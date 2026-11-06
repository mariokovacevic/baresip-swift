#include <re.h>
#include <rem.h>
#include <baresip.h>
#import <AVFoundation/AVFoundation.h>
#import <TargetConditionals.h>
#include "vidtoolbox.h"

static struct vidsrc *bsk_vidsrc;

struct vidsrc_st {
	void *capture;
	vidsrc_frame_h *frameh;
	vidsrc_error_h *errorh;
	void *arg;
	struct vidsz size;
	double fps;
	char device[64];
};

@interface BSKCapture : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *output;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) struct vidsrc_st *st;
@property (nonatomic, assign) BOOL front;
- (instancetype)initWithState:(struct vidsrc_st *)st;
- (BOOL)startWithDevice:(const char *)name;
- (void)stop;
- (BOOL)switchToDevice:(const char *)name;
@end

static AVCaptureDevicePosition position_for_name(const char *name, BOOL *known)
{
	*known = YES;
	if (!name || !*name || 0 == str_casecmp(name, "front"))
		return AVCaptureDevicePositionFront;
	if (0 == str_casecmp(name, "back"))
		return AVCaptureDevicePositionBack;
	*known = NO;
	return AVCaptureDevicePositionUnspecified;
}

static AVCaptureDevice *device_for_name(const char *name)
{
	BOOL known;
	AVCaptureDevicePosition pos = position_for_name(name, &known);
	AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession
		discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
		mediaType:AVMediaTypeVideo
		position:AVCaptureDevicePositionUnspecified];

	for (AVCaptureDevice *dev in discovery.devices) {
		if (known && dev.position == pos)
			return dev;
		if (!known && name && 0 == strcmp(name, dev.uniqueID.UTF8String))
			return dev;
		if (!known && name && 0 == strcmp(name, dev.localizedName.UTF8String))
			return dev;
	}

	return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

static NSString *preset_for_size(AVCaptureSession *session, AVCaptureDevice *dev,
				 const struct vidsz *sz)
{
	static const struct {
		unsigned w, h;
		__unsafe_unretained NSString *const *preset;
	} mapv[] = {
		{ 352, 288, &AVCaptureSessionPreset352x288 },
		{ 640, 480, &AVCaptureSessionPreset640x480 },
		{ 1280, 720, &AVCaptureSessionPreset1280x720 },
		{ 1920, 1080, &AVCaptureSessionPreset1920x1080 },
	};
	NSString *best = nil;

	for (size_t i = 0; i < RE_ARRAY_SIZE(mapv); i++) {
		NSString *preset = *mapv[i].preset;
		if (![session canSetSessionPreset:preset] ||
		    ![dev supportsAVCaptureSessionPreset:preset])
			continue;
		best = preset;
		if (mapv[i].w >= sz->w && mapv[i].h >= sz->h)
			break;
	}

	return best ? best : AVCaptureSessionPreset640x480;
}

@implementation BSKCapture

- (instancetype)initWithState:(struct vidsrc_st *)st
{
	self = [super init];
	if (!self)
		return nil;
	_st = st;
	_queue = dispatch_queue_create("baresipkit.capture", DISPATCH_QUEUE_SERIAL);
	_session = [[AVCaptureSession alloc] init];
	_output = [[AVCaptureVideoDataOutput alloc] init];
	_output.alwaysDiscardsLateVideoFrames = YES;
	_output.videoSettings = @{
		(id)kCVPixelBufferPixelFormatTypeKey:
			@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
	};
	[_output setSampleBufferDelegate:self queue:_queue];
	return self;
}

- (void)applyFrameRate:(AVCaptureDevice *)dev
{
	double fps = self.st->fps > 0 ? self.st->fps : 30;
	NSError *error = nil;

	if (![dev lockForConfiguration:&error])
		return;
	for (AVFrameRateRange *range in dev.activeFormat.videoSupportedFrameRateRanges) {
		if (fps >= range.minFrameRate && fps <= range.maxFrameRate) {
			dev.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)fps);
			dev.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)fps);
			break;
		}
	}
	[dev unlockForConfiguration];
}

- (void)applyOrientation
{
	AVCaptureConnection *conn = [self.output connectionWithMediaType:AVMediaTypeVideo];
	if (!conn)
		return;
#if TARGET_OS_IPHONE
	if ([conn isVideoRotationAngleSupported:90.0])
		conn.videoRotationAngle = 90.0;
#endif
	if (conn.isVideoMirroringSupported) {
		conn.automaticallyAdjustsVideoMirroring = NO;
		conn.videoMirrored = self.front;
	}
}

- (BOOL)startWithDevice:(const char *)name
{
	AVCaptureDevice *dev = device_for_name(name);
	NSError *error = nil;

	if (!dev)
		return NO;

	self.input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&error];
	if (!self.input)
		return NO;

	[self.session beginConfiguration];
	self.session.sessionPreset = preset_for_size(self.session, dev, &self.st->size);
	if ([self.session canAddInput:self.input])
		[self.session addInput:self.input];
	if ([self.session canAddOutput:self.output])
		[self.session addOutput:self.output];
	[self.session commitConfiguration];

	self.front = (dev.position == AVCaptureDevicePositionFront);
	[self applyFrameRate:dev];
	[self applyOrientation];
	[self.session startRunning];

	return self.session.isRunning;
}

- (BOOL)switchToDevice:(const char *)name
{
	AVCaptureDevice *dev = device_for_name(name);
	NSError *error = nil;
	AVCaptureDeviceInput *input;

	if (!dev || (self.input && dev == self.input.device))
		return dev != nil;

	input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&error];
	if (!input)
		return NO;

	[self.session beginConfiguration];
	if (self.input)
		[self.session removeInput:self.input];
	self.session.sessionPreset = preset_for_size(self.session, dev, &self.st->size);
	if ([self.session canAddInput:input]) {
		[self.session addInput:input];
		self.input = input;
	}
	else if (self.input && [self.session canAddInput:self.input]) {
		[self.session addInput:self.input];
	}
	[self.session commitConfiguration];

	self.front = (dev.position == AVCaptureDevicePositionFront);
	[self applyFrameRate:dev];
	[self applyOrientation];
	return YES;
}

- (void)stop
{
	[self.output setSampleBufferDelegate:nil queue:nil];
	if (self.session.isRunning)
		[self.session stopRunning];
	[self.session beginConfiguration];
	if (self.input)
		[self.session removeInput:self.input];
	[self.session removeOutput:self.output];
	[self.session commitConfiguration];
	self.input = nil;
	self.st = NULL;
}

- (void)captureOutput:(AVCaptureOutput *)output
	didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	fromConnection:(AVCaptureConnection *)connection
{
	struct vidsrc_st *st = self.st;
	CVImageBufferRef pb;
	struct vidframe vf;
	CMTime ts;
	(void)output;
	(void)connection;

	if (!st || !st->frameh)
		return;

	pb = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!pb || CVPixelBufferGetPlaneCount(pb) != 2)
		return;

	if (kCVReturnSuccess != CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly))
		return;

	memset(&vf, 0, sizeof(vf));
	vf.fmt = VID_FMT_NV12;
	vf.size.w = (unsigned)CVPixelBufferGetWidth(pb);
	vf.size.h = (unsigned)CVPixelBufferGetHeight(pb);
	vf.data[0] = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
	vf.data[1] = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
	vf.linesize[0] = (uint16_t)CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
	vf.linesize[1] = (uint16_t)CVPixelBufferGetBytesPerRowOfPlane(pb, 1);

	ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
	st->frameh(&vf, (uint64_t)(CMTimeGetSeconds(ts) * VIDEO_TIMEBASE), st->arg);

	CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
}

@end

static void destructor(void *arg)
{
	struct vidsrc_st *st = arg;
	BSKCapture *cap = (__bridge_transfer BSKCapture *)st->capture;

	st->frameh = NULL;
	if (cap)
		[cap stop];
	cap = nil;
	st->capture = NULL;
}

static int bskcapture_alloc(struct vidsrc_st **stp, const struct vidsrc *vs,
			    struct vidsrc_prm *prm, const struct vidsz *size,
			    const char *fmt, const char *dev,
			    vidsrc_frame_h *frameh, vidsrc_packet_h *packeth,
			    vidsrc_error_h *errorh, void *arg)
{
	struct vidsrc_st *st;
	BSKCapture *cap;
	(void)vs;
	(void)fmt;
	(void)packeth;

	if (!stp || !size || !frameh)
		return EINVAL;

	st = mem_zalloc(sizeof(*st), destructor);
	if (!st)
		return ENOMEM;

	st->frameh = frameh;
	st->errorh = errorh;
	st->arg = arg;
	st->size = *size;
	st->fps = prm ? prm->fps : 30;
	str_ncpy(st->device, str_isset(dev) ? dev : "front", sizeof(st->device));

	cap = [[BSKCapture alloc] initWithState:st];
	if (!cap || ![cap startWithDevice:st->device]) {
		warning("bskcapture: cannot start camera '%s'\n", st->device);
		cap = nil;
		mem_deref(st);
		return ENODEV;
	}

	st->capture = (__bridge_retained void *)cap;
	info("bskcapture: device=%s %ux%u %.0f fps\n", st->device, size->w,
	     size->h, st->fps);

	*stp = st;
	return 0;
}

static void bskcapture_update(struct vidsrc_st *st, struct vidsrc_prm *prm,
			      const char *dev)
{
	BSKCapture *cap;
	(void)prm;

	if (!st || !st->capture || !str_isset(dev))
		return;

	cap = (__bridge BSKCapture *)st->capture;
	if ([cap switchToDevice:dev])
		str_ncpy(st->device, dev, sizeof(st->device));
}

int bskcapture_init(void)
{
	int err;

	err = vidsrc_register(&bsk_vidsrc, baresip_vidsrcl(), "bskcapture",
			      bskcapture_alloc, bskcapture_update);
	if (err)
		return err;

	@autoreleasepool {
		AVCaptureDeviceDiscoverySession *discovery =
			[AVCaptureDeviceDiscoverySession
				discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
				mediaType:AVMediaTypeVideo
				position:AVCaptureDevicePositionUnspecified];
		bool have_front = false, have_back = false;

		for (AVCaptureDevice *dev in discovery.devices) {
			if (dev.position == AVCaptureDevicePositionFront && !have_front) {
				err |= mediadev_add(&bsk_vidsrc->dev_list, "front");
				have_front = true;
			}
			else if (dev.position == AVCaptureDevicePositionBack && !have_back) {
				err |= mediadev_add(&bsk_vidsrc->dev_list, "back");
				have_back = true;
			}
			else {
				err |= mediadev_add(&bsk_vidsrc->dev_list,
						    dev.localizedName.UTF8String);
			}
		}
	}

	return err;
}

void bskcapture_close(void)
{
	bsk_vidsrc = mem_deref(bsk_vidsrc);
}
