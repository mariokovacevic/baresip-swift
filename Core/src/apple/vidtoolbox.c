#include <string.h>
#include <re.h>
#include <rem.h>
#include <baresip.h>
#include <re_h264.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VideoToolbox.h>
#include "vidtoolbox.h"

enum {
	DECODE_MAXSZ = 1024 * 1024,
	MAX_PARAM_SET = 256
};

struct videnc_state {
	VTCompressionSessionRef sess;
	struct videnc_param prm;
	videnc_packet_h *pkth;
	const struct video *vid;
	unsigned width;
	unsigned height;
	double fps;
	struct mbuf *out;
	mtx_t mtx;
	bool out_keyframe;
	uint64_t out_ts;
	int out_err;
};

struct viddec_state {
	VTDecompressionSessionRef sess;
	CMVideoFormatDescriptionRef fmtdesc;
	struct mbuf *mb;
	uint8_t sps[MAX_PARAM_SET];
	size_t sps_len;
	uint8_t pps[MAX_PARAM_SET];
	size_t pps_len;
	bool got_keyframe;
	bool frag;
	size_t frag_start;
	uint16_t frag_seq;
	CVPixelBufferRef frame;
	CVPixelBufferRef prev;
	bool locked;
	unsigned n_keyframes;
	unsigned n_lost;
};


static const uint8_t startcode[4] = { 0, 0, 0, 1 };


static uint32_t packetization_mode(const char *fmtp)
{
	struct pl pl, mode;

	if (!fmtp)
		return 0;

	pl_set_str(&pl, fmtp);
	if (fmt_param_get(&pl, "packetization-mode", &mode))
		return pl_u32(&mode);

	return 0;
}


static int write_annexb_from_avcc(struct mbuf *out, const uint8_t *data,
				  size_t len, size_t nal_len_size)
{
	size_t pos = 0;
	int err = 0;

	while (pos + nal_len_size <= len) {
		size_t nal_size = 0, i;

		for (i = 0; i < nal_len_size; i++)
			nal_size = (nal_size << 8) | data[pos + i];
		pos += nal_len_size;
		if (nal_size == 0 || pos + nal_size > len)
			return EBADMSG;

		err |= mbuf_write_mem(out, startcode, sizeof(startcode));
		err |= mbuf_write_mem(out, data + pos, nal_size);
		pos += nal_size;
	}

	return err;
}


static void enc_output(void *outputCallbackRefCon, void *sourceFrameRefCon,
		       OSStatus status, VTEncodeInfoFlags infoFlags,
		       CMSampleBufferRef sampleBuffer)
{
	struct videnc_state *st = outputCallbackRefCon;
	CMBlockBufferRef block;
	CMFormatDescriptionRef fmt;
	size_t total = 0, nal_len_size = 4;
	char *data = NULL;
	bool keyframe = false;
	CFArrayRef attachments;
	int err = 0;
	(void)sourceFrameRefCon;
	(void)infoFlags;

	if (!st)
		return;

	mtx_lock(&st->mtx);
	mbuf_rewind(st->out);
	st->out_keyframe = false;

	if (status != noErr || !sampleBuffer) {
		st->out_err = EIO;
		goto out;
	}

	attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
	if (attachments && CFArrayGetCount(attachments) > 0) {
		CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
		keyframe = !CFDictionaryContainsKey(
			dict, kCMSampleAttachmentKey_NotSync);
	}

	fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
	if (keyframe && fmt) {
		size_t count = 0;
		int nal_hdr_len = 4;
		size_t i;

		(void)CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
			fmt, 0, NULL, NULL, &count, &nal_hdr_len);
		nal_len_size = (size_t)nal_hdr_len;

		for (i = 0; i < count; i++) {
			const uint8_t *ps = NULL;
			size_t ps_len = 0;

			if (noErr != CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
				    fmt, i, &ps, &ps_len, NULL, NULL))
				continue;
			err |= mbuf_write_mem(st->out, startcode,
					      sizeof(startcode));
			err |= mbuf_write_mem(st->out, ps, ps_len);
		}
	}
	else if (fmt) {
		int nal_hdr_len = 4;
		(void)CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
			fmt, 0, NULL, NULL, NULL, &nal_hdr_len);
		nal_len_size = (size_t)nal_hdr_len;
	}

	block = CMSampleBufferGetDataBuffer(sampleBuffer);
	if (!block ||
	    noErr != CMBlockBufferGetDataPointer(block, 0, NULL, &total,
						 &data)) {
		st->out_err = EIO;
		goto out;
	}

	err |= write_annexb_from_avcc(st->out, (const uint8_t *)data, total,
				      nal_len_size);
	st->out_err = err;
	st->out_keyframe = keyframe;

 out:
	mtx_unlock(&st->mtx);
}


static void enc_destructor(void *arg)
{
	struct videnc_state *st = arg;

	if (st->sess) {
		VTCompressionSessionInvalidate(st->sess);
		CFRelease(st->sess);
	}
	mem_deref(st->out);
	mtx_destroy(&st->mtx);
}


static void set_int_prop(VTCompressionSessionRef sess, CFStringRef key,
			 int value)
{
	CFNumberRef n = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType,
				       &value);
	if (n) {
		VTSessionSetProperty(sess, key, n);
		CFRelease(n);
	}
}


static int open_encoder(struct videnc_state *st, unsigned width,
			unsigned height)
{
	OSStatus ret;
	CFMutableDictionaryRef src_attrs;
	int pixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
	CFNumberRef n;

	if (st->sess) {
		VTCompressionSessionInvalidate(st->sess);
		CFRelease(st->sess);
		st->sess = NULL;
	}

	src_attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
					      &kCFTypeDictionaryKeyCallBacks,
					      &kCFTypeDictionaryValueCallBacks);
	n = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pixfmt);
	CFDictionarySetValue(src_attrs, kCVPixelBufferPixelFormatTypeKey, n);
	CFRelease(n);

	ret = VTCompressionSessionCreate(kCFAllocatorDefault, (int32_t)width,
					 (int32_t)height, kCMVideoCodecType_H264,
					 NULL, src_attrs, NULL, enc_output, st,
					 &st->sess);
	CFRelease(src_attrs);
	if (ret != noErr || !st->sess) {
		warning("vidtoolbox: VTCompressionSessionCreate failed (%d)\n",
			(int)ret);
		return ENOSYS;
	}

	VTSessionSetProperty(st->sess, kVTCompressionPropertyKey_RealTime,
			     kCFBooleanTrue);
	VTSessionSetProperty(st->sess,
			     kVTCompressionPropertyKey_AllowFrameReordering,
			     kCFBooleanFalse);
	VTSessionSetProperty(st->sess, kVTCompressionPropertyKey_ProfileLevel,
			     kVTProfileLevel_H264_Baseline_AutoLevel);
	VTSessionSetProperty(st->sess,
			     kVTCompressionPropertyKey_H264EntropyMode,
			     kVTH264EntropyMode_CAVLC);
	set_int_prop(st->sess, kVTCompressionPropertyKey_AverageBitRate,
		     (int)st->prm.bitrate);
	set_int_prop(st->sess, kVTCompressionPropertyKey_ExpectedFrameRate,
		     (int)(st->fps > 0 ? st->fps : 30));
	set_int_prop(st->sess, kVTCompressionPropertyKey_MaxKeyFrameInterval,
		     (int)((st->fps > 0 ? st->fps : 30) * 2));
	set_int_prop(st->sess,
		     kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, 2);

	VTCompressionSessionPrepareToEncodeFrames(st->sess);

	st->width = width;
	st->height = height;

	info("vidtoolbox: encoder %ux%u %u bit/s %.0f fps\n", width, height,
	     st->prm.bitrate, st->fps);

	return 0;
}


int vidtoolbox_encode_update(struct videnc_state **vesp,
			     const struct vidcodec *vc,
			     struct videnc_param *prm, const char *fmtp,
			     videnc_packet_h *pkth, const struct video *vid)
{
	struct videnc_state *st;
	(void)fmtp;

	if (!vesp || !vc || !prm || !pkth)
		return EINVAL;

	if (*vesp) {
		st = *vesp;
		st->prm = *prm;
		st->fps = prm->fps;
		if (st->sess) {
			set_int_prop(st->sess,
				     kVTCompressionPropertyKey_AverageBitRate,
				     (int)prm->bitrate);
		}
		return 0;
	}

	st = mem_zalloc(sizeof(*st), enc_destructor);
	if (!st)
		return ENOMEM;

	st->prm = *prm;
	st->fps = prm->fps;
	st->pkth = pkth;
	st->vid = vid;
	mtx_init(&st->mtx, mtx_plain);
	st->out = mbuf_alloc(64 * 1024);
	if (!st->out) {
		mem_deref(st);
		return ENOMEM;
	}

	*vesp = st;
	return 0;
}


static int fill_pixel_buffer(CVPixelBufferRef pb, const struct vidframe *frame)
{
	size_t h = frame->size.h, w = frame->size.w, row;
	uint8_t *y_dst, *uv_dst;
	size_t y_stride, uv_stride;

	if (noErr != CVPixelBufferLockBaseAddress(pb, 0))
		return EIO;

	y_dst = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
	uv_dst = CVPixelBufferGetBaseAddressOfPlane(pb, 1);
	y_stride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
	uv_stride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1);

	for (row = 0; row < h; row++)
		memcpy(y_dst + row * y_stride,
		       frame->data[0] + row * frame->linesize[0], w);

	if (frame->fmt == VID_FMT_NV12) {
		for (row = 0; row < (h + 1) / 2; row++)
			memcpy(uv_dst + row * uv_stride,
			       frame->data[1] + row * frame->linesize[1],
			       (w + 1) & ~1u);
	}
	else {
		for (row = 0; row < (h + 1) / 2; row++) {
			const uint8_t *u = frame->data[1] +
				row * frame->linesize[1];
			const uint8_t *v = frame->data[2] +
				row * frame->linesize[2];
			uint8_t *d = uv_dst + row * uv_stride;
			size_t x;
			for (x = 0; x < (w + 1) / 2; x++) {
				d[2 * x] = u[x];
				d[2 * x + 1] = v[x];
			}
		}
	}

	CVPixelBufferUnlockBaseAddress(pb, 0);
	return 0;
}


int vidtoolbox_encode(struct videnc_state *st, bool update,
		      const struct vidframe *frame, uint64_t timestamp)
{
	CVPixelBufferPoolRef pool;
	CVPixelBufferRef pb = NULL;
	CFDictionaryRef props = NULL;
	CMTime pts;
	OSStatus ret;
	int err;

	if (!st || !frame)
		return EINVAL;

	if (frame->fmt != VID_FMT_YUV420P && frame->fmt != VID_FMT_NV12)
		return ENOTSUP;

	if (!st->sess || st->width != frame->size.w ||
	    st->height != frame->size.h) {
		err = open_encoder(st, frame->size.w, frame->size.h);
		if (err)
			return err;
		update = true;
	}

	pool = VTCompressionSessionGetPixelBufferPool(st->sess);
	if (!pool)
		return ENOMEM;

	if (kCVReturnSuccess !=
	    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb))
		return ENOMEM;

	err = fill_pixel_buffer(pb, frame);
	if (err) {
		CFRelease(pb);
		return err;
	}

	if (update) {
		const void *keys[] = { kVTEncodeFrameOptionKey_ForceKeyFrame };
		const void *values[] = { kCFBooleanTrue };
		props = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1,
					   &kCFTypeDictionaryKeyCallBacks,
					   &kCFTypeDictionaryValueCallBacks);
	}

	pts = CMTimeMake((int64_t)timestamp, VIDEO_TIMEBASE);

	mtx_lock(&st->mtx);
	st->out_err = 0;
	mbuf_rewind(st->out);
	mtx_unlock(&st->mtx);

	ret = VTCompressionSessionEncodeFrame(st->sess, pb, pts, kCMTimeInvalid,
					      props, NULL, NULL);
	if (props)
		CFRelease(props);
	CFRelease(pb);
	if (ret != noErr) {
		warning("vidtoolbox: encode frame failed (%d)\n", (int)ret);
		return EIO;
	}

	VTCompressionSessionCompleteFrames(st->sess, pts);

	mtx_lock(&st->mtx);
	err = st->out_err;
	if (!err && st->out->end > 0) {
		uint64_t rtp_ts = video_calc_rtp_timestamp_fix(timestamp);
		err = h264_packetize(rtp_ts, st->out->buf, st->out->end,
				     st->prm.pktsize, (h264_packet_h *)st->pkth,
				     (void *)st->vid);
	}
	mbuf_rewind(st->out);
	mtx_unlock(&st->mtx);

	return err;
}


static void dec_output(void *decompressionOutputRefCon,
		       void *sourceFrameRefCon, OSStatus status,
		       VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer,
		       CMTime presentationTimeStamp, CMTime presentationDuration)
{
	struct viddec_state *st = decompressionOutputRefCon;
	(void)sourceFrameRefCon;
	(void)infoFlags;
	(void)presentationTimeStamp;
	(void)presentationDuration;

	if (!st || status != noErr || !imageBuffer)
		return;

	if (st->frame)
		CFRelease(st->frame);
	st->frame = (CVPixelBufferRef)CFRetain(imageBuffer);
}


static void release_prev(struct viddec_state *st)
{
	if (st->prev) {
		if (st->locked)
			CVPixelBufferUnlockBaseAddress(st->prev, kCVPixelBufferLock_ReadOnly);
		CFRelease(st->prev);
		st->prev = NULL;
		st->locked = false;
	}
}


static void dec_destructor(void *arg)
{
	struct viddec_state *st = arg;

	release_prev(st);
	if (st->frame)
		CFRelease(st->frame);
	if (st->sess) {
		VTDecompressionSessionInvalidate(st->sess);
		CFRelease(st->sess);
	}
	if (st->fmtdesc)
		CFRelease(st->fmtdesc);
	mem_deref(st->mb);
}


int vidtoolbox_decode_update(struct viddec_state **vdsp,
			     const struct vidcodec *vc, const char *fmtp,
			     const struct video *vid)
{
	struct viddec_state *st;
	(void)vc;
	(void)fmtp;
	(void)vid;

	if (!vdsp)
		return EINVAL;
	if (*vdsp)
		return 0;

	st = mem_zalloc(sizeof(*st), dec_destructor);
	if (!st)
		return ENOMEM;

	st->mb = mbuf_alloc(DECODE_MAXSZ);
	if (!st->mb) {
		mem_deref(st);
		return ENOMEM;
	}

	*vdsp = st;
	return 0;
}


static int open_decoder(struct viddec_state *st)
{
	const uint8_t *params[2] = { st->sps, st->pps };
	const size_t sizes[2] = { st->sps_len, st->pps_len };
	VTDecompressionOutputCallbackRecord cb = { dec_output, st };
	CFMutableDictionaryRef attrs;
	int pixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
	CFNumberRef n;
	OSStatus ret;

	if (st->sess) {
		VTDecompressionSessionInvalidate(st->sess);
		CFRelease(st->sess);
		st->sess = NULL;
	}
	if (st->fmtdesc) {
		CFRelease(st->fmtdesc);
		st->fmtdesc = NULL;
	}

	ret = CMVideoFormatDescriptionCreateFromH264ParameterSets(
		kCFAllocatorDefault, 2, params, sizes, 4, &st->fmtdesc);
	if (ret != noErr) {
		warning("vidtoolbox: format description failed (%d)\n", (int)ret);
		return EBADMSG;
	}

	attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
					  &kCFTypeDictionaryKeyCallBacks,
					  &kCFTypeDictionaryValueCallBacks);
	n = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pixfmt);
	CFDictionarySetValue(attrs, kCVPixelBufferPixelFormatTypeKey, n);
	CFRelease(n);

	ret = VTDecompressionSessionCreate(kCFAllocatorDefault, st->fmtdesc,
					   NULL, attrs, &cb, &st->sess);
	CFRelease(attrs);
	if (ret != noErr || !st->sess) {
		warning("vidtoolbox: VTDecompressionSessionCreate failed (%d)\n",
			(int)ret);
		return ENOSYS;
	}

	VTSessionSetProperty(st->sess, kVTDecompressionPropertyKey_RealTime,
			     kCFBooleanTrue);

	info("vidtoolbox: decoder opened\n");
	return 0;
}


static bool param_set_changed(const uint8_t *old, size_t old_len,
			      const uint8_t *nal, size_t len)
{
	return old_len != len || 0 != memcmp(old, nal, len);
}


static int decode_access_unit(struct viddec_state *st, struct vidframe *frame,
			      bool *intra)
{
	const uint8_t *p = st->mb->buf;
	const uint8_t *end = st->mb->buf + st->mb->end;
	struct mbuf *avcc;
	bool reopen = false, have_slice = false, keyframe = false;
	CMBlockBufferRef block = NULL;
	CMSampleBufferRef sample = NULL;
	OSStatus ret;
	int err = 0;

	avcc = mbuf_alloc(st->mb->end + 64);
	if (!avcc)
		return ENOMEM;

	p = h264_find_startcode(p, end);
	while (p < end) {
		const uint8_t *next;
		const uint8_t *nal;
		size_t nal_len;
		uint8_t type;

		while (p < end && *p == 0)
			p++;
		if (p < end && *p == 1)
			p++;
		nal = p;
		next = h264_find_startcode(nal, end);
		nal_len = (size_t)(next - nal);
		while (nal_len && nal[nal_len - 1] == 0)
			nal_len--;
		if (!nal_len)
			break;

		type = nal[0] & 0x1f;
		if (type == H264_NALU_SPS && nal_len <= MAX_PARAM_SET) {
			if (param_set_changed(st->sps, st->sps_len, nal, nal_len)) {
				memcpy(st->sps, nal, nal_len);
				st->sps_len = nal_len;
				reopen = true;
			}
		}
		else if (type == H264_NALU_PPS && nal_len <= MAX_PARAM_SET) {
			if (param_set_changed(st->pps, st->pps_len, nal, nal_len)) {
				memcpy(st->pps, nal, nal_len);
				st->pps_len = nal_len;
				reopen = true;
			}
		}
		else if (type == H264_NALU_IDR_SLICE || type == H264_NALU_SLICE) {
			uint8_t len4[4] = {
				(uint8_t)(nal_len >> 24), (uint8_t)(nal_len >> 16),
				(uint8_t)(nal_len >> 8), (uint8_t)nal_len
			};
			err |= mbuf_write_mem(avcc, len4, 4);
			err |= mbuf_write_mem(avcc, nal, nal_len);
			have_slice = true;
			if (type == H264_NALU_IDR_SLICE)
				keyframe = true;
		}

		p = next;
	}

	if (err)
		goto out;

	if ((reopen || !st->sess) && st->sps_len && st->pps_len) {
		err = open_decoder(st);
		if (err)
			goto out;
	}

	if (!st->sess || !have_slice) {
		err = st->sess ? 0 : EPROTO;
		goto out;
	}

	if (!st->got_keyframe && !keyframe) {
		err = EPROTO;
		goto out;
	}

	ret = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, avcc->buf,
						 avcc->end, kCFAllocatorNull, NULL,
						 0, avcc->end, 0, &block);
	if (ret != noErr) {
		err = ENOMEM;
		goto out;
	}

	ret = CMSampleBufferCreateReady(kCFAllocatorDefault, block, st->fmtdesc,
					1, 0, NULL, 0, NULL, &sample);
	if (ret != noErr) {
		err = ENOMEM;
		goto out;
	}

	if (st->frame) {
		CFRelease(st->frame);
		st->frame = NULL;
	}

	ret = VTDecompressionSessionDecodeFrame(st->sess, sample, 0, NULL, NULL);
	if (ret != noErr) {
		if (ret == kVTInvalidSessionErr) {
			VTDecompressionSessionInvalidate(st->sess);
			CFRelease(st->sess);
			st->sess = NULL;
			st->got_keyframe = false;
		}
		err = EPROTO;
		goto out;
	}

	if (!st->frame) {
		err = 0;
		goto out;
	}

	release_prev(st);
	st->prev = st->frame;
	st->frame = NULL;

	if (noErr != CVPixelBufferLockBaseAddress(st->prev,
						  kCVPixelBufferLock_ReadOnly)) {
		err = EIO;
		goto out;
	}
	st->locked = true;

	memset(frame, 0, sizeof(*frame));
	frame->fmt = VID_FMT_NV12;
	frame->size.w = (unsigned)CVPixelBufferGetWidth(st->prev);
	frame->size.h = (unsigned)CVPixelBufferGetHeight(st->prev);
	frame->data[0] = CVPixelBufferGetBaseAddressOfPlane(st->prev, 0);
	frame->data[1] = CVPixelBufferGetBaseAddressOfPlane(st->prev, 1);
	frame->linesize[0] = (uint16_t)CVPixelBufferGetBytesPerRowOfPlane(st->prev, 0);
	frame->linesize[1] = (uint16_t)CVPixelBufferGetBytesPerRowOfPlane(st->prev, 1);

	if (keyframe) {
		*intra = true;
		st->got_keyframe = true;
		++st->n_keyframes;
	}

 out:
	if (sample)
		CFRelease(sample);
	if (block)
		CFRelease(block);
	mem_deref(avcc);

	return err;
}


static inline void fragment_rewind(struct viddec_state *st)
{
	st->mb->pos = st->frag_start;
	st->mb->end = st->frag_start;
}


int vidtoolbox_decode(struct viddec_state *st, struct vidframe *frame,
		      struct viddec_packet *pkt)
{
	struct h264_nal_header hdr;
	struct mbuf *src;
	const uint8_t nal_seq[3] = { 0, 0, 1 };
	int err;

	if (!st || !frame || !pkt || !pkt->mb)
		return EINVAL;

	pkt->intra = false;
	src = pkt->mb;

	err = h264_nal_header_decode(&hdr, src);
	if (err)
		return err;

	if (hdr.f)
		return EBADMSG;

	if (st->frag && hdr.type != H264_NALU_FU_A) {
		fragment_rewind(st);
		st->frag = false;
		++st->n_lost;
	}

	if (1 <= hdr.type && hdr.type <= 23) {
		--src->pos;
		err  = mbuf_write_mem(st->mb, nal_seq, 3);
		err |= mbuf_write_mem(st->mb, mbuf_buf(src), mbuf_get_left(src));
		if (err)
			goto out;
	}
	else if (H264_NALU_FU_A == hdr.type) {
		struct h264_fu fu;

		err = h264_fu_hdr_decode(&fu, src);
		if (err)
			return err;
		hdr.type = fu.type;

		if (fu.s) {
			if (st->frag) {
				fragment_rewind(st);
				++st->n_lost;
			}
			st->frag_start = st->mb->pos;
			st->frag = true;
			mbuf_write_mem(st->mb, nal_seq, 3);
			err = h264_nal_header_encode(st->mb, &hdr);
			if (err)
				goto out;
		}
		else {
			if (!st->frag) {
				++st->n_lost;
				return 0;
			}
			if (rtp_seq_diff(st->frag_seq, pkt->hdr->seq) != 1) {
				fragment_rewind(st);
				st->frag = false;
				++st->n_lost;
				return 0;
			}
		}

		err = mbuf_write_mem(st->mb, mbuf_buf(src), mbuf_get_left(src));
		if (err)
			goto out;

		if (fu.e)
			st->frag = false;

		st->frag_seq = pkt->hdr->seq;
	}
	else if (H264_NALU_STAP_A == hdr.type) {
		err = h264_stap_decode_annexb(st->mb, src);
		if (err)
			goto out;
	}
	else {
		return EBADMSG;
	}

	if (!pkt->hdr->m) {
		if (st->mb->end > DECODE_MAXSZ) {
			err = ENOMEM;
			goto out;
		}
		return 0;
	}

	if (st->frag) {
		err = EPROTO;
		goto out;
	}

	err = decode_access_unit(st, frame, &pkt->intra);

 out:
	mbuf_rewind(st->mb);
	st->frag = false;

	return err;
}


int vidtoolbox_fmtp_enc(struct mbuf *mb, const struct sdp_format *fmt,
			bool offer, void *arg)
{
	struct vidcodec *vc = arg;
	(void)offer;

	if (!mb || !fmt || !vc)
		return 0;

	return mbuf_printf(mb, "a=fmtp:%s %s;profile-level-id=42e01f\r\n",
			   fmt->id, vc->variant);
}


bool vidtoolbox_fmtp_cmp(const char *lfmtp, const char *rfmtp, void *arg)
{
	const struct vidcodec *vc = arg;
	(void)lfmtp;

	if (!vc)
		return false;

	return packetization_mode(vc->variant) == packetization_mode(rfmtp);
}


static struct vidcodec h264_mode1 = {
	.name      = "H264",
	.variant   = "packetization-mode=1",
	.encupdh   = vidtoolbox_encode_update,
	.ench      = vidtoolbox_encode,
	.decupdh   = vidtoolbox_decode_update,
	.dech      = vidtoolbox_decode,
	.fmtp_ench = vidtoolbox_fmtp_enc,
	.fmtp_cmph = vidtoolbox_fmtp_cmp,
};

static struct vidcodec h264_mode0 = {
	.name      = "H264",
	.variant   = "packetization-mode=0",
	.encupdh   = vidtoolbox_encode_update,
	.ench      = vidtoolbox_encode,
	.decupdh   = vidtoolbox_decode_update,
	.dech      = vidtoolbox_decode,
	.fmtp_ench = vidtoolbox_fmtp_enc,
	.fmtp_cmph = vidtoolbox_fmtp_cmp,
};


int vidtoolbox_init(void)
{
	vidcodec_register(baresip_vidcodecl(), &h264_mode1);
	vidcodec_register(baresip_vidcodecl(), &h264_mode0);
	info("vidtoolbox: H264 codec registered (VideoToolbox)\n");
	return 0;
}


void vidtoolbox_close(void)
{
	vidcodec_unregister(&h264_mode0);
	vidcodec_unregister(&h264_mode1);
}
