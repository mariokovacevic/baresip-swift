#include <pthread.h>
#include <string.h>
#include <re.h>
#include <rem.h>
#include <baresip.h>
#include "baresip_kit_android.h"
#include "bsk_android.h"
#include "../bsk_frame.h"

enum { MAX_SOURCES = 4 };

struct vidsrc_st {
	vidsrc_frame_h *frameh;
	void *arg;
	struct vidsz size;
	double fps;
	char device[64];
	bool started;
};

static struct vidsrc *bsk_vidsrc;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static bsk_camera_host host;
static struct vidsrc_st *sources[MAX_SOURCES];


void bsk_camera_set_host(const bsk_camera_host *h)
{
	pthread_mutex_lock(&lock);
	if (h)
		host = *h;
	else
		memset(&host, 0, sizeof(host));
	pthread_mutex_unlock(&lock);
}


static bool registered(const struct vidsrc_st *st)
{
	for (int i = 0; i < MAX_SOURCES; i++) {
		if (sources[i] == st)
			return true;
	}
	return false;
}


static enum vidfmt frame_format(bsk_pixel_format format)
{
	switch (format) {
	case BSK_PIX_I420: return VID_FMT_YUV420P;
	case BSK_PIX_NV12: return VID_FMT_NV12;
	default: return VID_FMT_N;
	}
}


bool bsk_camera_push(void *source, const bsk_video_frame *frame)
{
	struct vidsrc_st *st = source;
	struct vidframe vf;
	bool delivered = false;

	if (!st || !frame)
		return false;

	memset(&vf, 0, sizeof(vf));
	vf.fmt = frame_format(frame->format);
	if (vf.fmt == VID_FMT_N || !bsk_frame_strides_ok(frame))
		return false;
	vf.size.w = frame->width;
	vf.size.h = frame->height;
	for (int i = 0; i < 3; i++) {
		vf.data[i] = (uint8_t *)frame->planes[i];
		vf.linesize[i] = (uint16_t)frame->strides[i];
	}

	pthread_mutex_lock(&lock);
	if (registered(st) && st->frameh) {
		st->frameh(&vf, frame->timestamp_us, st->arg);
		delivered = true;
	}
	pthread_mutex_unlock(&lock);

	return delivered;
}


static void destructor(void *arg)
{
	struct vidsrc_st *st = arg;
	bsk_camera_host h;
	bool started;

	pthread_mutex_lock(&lock);
	for (int i = 0; i < MAX_SOURCES; i++) {
		if (sources[i] == st)
			sources[i] = NULL;
	}
	h = host;
	started = st->started;
	st->frameh = NULL;
	pthread_mutex_unlock(&lock);

	if (started && h.stop)
		h.stop(st, h.user);
}


static int bskcamera_alloc(struct vidsrc_st **stp, const struct vidsrc *vs,
			   struct vidsrc_prm *prm, const struct vidsz *size,
			   const char *fmt, const char *dev,
			   vidsrc_frame_h *frameh, vidsrc_packet_h *packeth,
			   vidsrc_error_h *errorh, void *arg)
{
	struct vidsrc_st *st;
	bsk_camera_host h;
	int slot = -1;
	int err;
	(void)vs;
	(void)fmt;
	(void)packeth;
	(void)errorh;

	if (!stp || !size || !frameh)
		return EINVAL;

	st = mem_zalloc(sizeof(*st), destructor);
	if (!st)
		return ENOMEM;

	st->frameh = frameh;
	st->arg = arg;
	st->size = *size;
	st->fps = prm ? prm->fps : 30;
	str_ncpy(st->device, str_isset(dev) ? dev : "front",
		 sizeof(st->device));

	pthread_mutex_lock(&lock);
	h = host;
	for (int i = 0; i < MAX_SOURCES && slot < 0; i++) {
		if (!sources[i])
			slot = i;
	}
	if (slot >= 0)
		sources[slot] = st;
	pthread_mutex_unlock(&lock);

	if (slot < 0 || !h.start) {
		warning("bskcamera: no camera host for '%s'\n", st->device);
		mem_deref(st);
		return ENODEV;
	}

	err = h.start(st, st->device, size->w, size->h,
		      (uint32_t)(st->fps + 0.5), h.user);
	if (err) {
		warning("bskcamera: cannot start camera '%s' (%m)\n",
			st->device, err);
		mem_deref(st);
		return err;
	}
	st->started = true;

	info("bskcamera: device=%s %ux%u %.0f fps\n", st->device, size->w,
	     size->h, st->fps);

	*stp = st;
	return 0;
}


static void bskcamera_update(struct vidsrc_st *st, struct vidsrc_prm *prm,
			     const char *dev)
{
	bsk_camera_host h;
	(void)prm;

	if (!st || !str_isset(dev))
		return;

	pthread_mutex_lock(&lock);
	h = host;
	pthread_mutex_unlock(&lock);

	if (h.switch_device && 0 == h.switch_device(st, dev, h.user))
		str_ncpy(st->device, dev, sizeof(st->device));
}


int bskcamera_init(void)
{
	int err;

	err = vidsrc_register(&bsk_vidsrc, baresip_vidsrcl(), "bskcamera",
			      bskcamera_alloc, bskcamera_update);
	if (err)
		return err;

	err = mediadev_add(&bsk_vidsrc->dev_list, "front");
	err |= mediadev_add(&bsk_vidsrc->dev_list, "back");

	return err;
}


void bskcamera_close(void)
{
	bsk_vidsrc = mem_deref(bsk_vidsrc);
}
