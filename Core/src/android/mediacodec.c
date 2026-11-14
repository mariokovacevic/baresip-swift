#include <string.h>
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaFormat.h>
#include <re.h>
#include <rem.h>
#include <baresip.h>
#include "bsk_android.h"
#include "../bsk_h264.h"
#include "../bsk_frame.h"

enum {
	COLOR_PLANAR = 19,
	COLOR_SEMIPLANAR = 21,
	COLOR_FLEXIBLE = 0x7f420888,
	PROFILE_BASELINE = 1,
	LEVEL_31 = 0x200,
	DEQUEUE_INPUT_US = 20000,
	DEQUEUE_OUTPUT_US = 10000,
	KEYFRAME_INTERVAL_S = 3,
};

static const char *mime = "video/avc";
static const uint8_t startcode[4] = { 0, 0, 0, 1 };

struct videnc_state {
	AMediaCodec *codec;
	struct videnc_param prm;
	videnc_packet_h *pkth;
	const struct video *vid;
	unsigned width;
	unsigned height;
	int32_t color;
	int32_t stride;
	int32_t slice;
	uint8_t config[2 * BSK_H264_MAX_PARAM_SET];
	size_t config_len;
	struct mbuf *out;
};

struct viddec_state {
	AMediaCodec *codec;
	struct bsk_h264_depack depack;
	uint8_t sps[BSK_H264_MAX_PARAM_SET];
	size_t sps_len;
	uint8_t pps[BSK_H264_MAX_PARAM_SET];
	size_t pps_len;
	bool got_keyframe;
	int32_t width;
	int32_t height;
	int32_t stride;
	int32_t slice;
	int32_t color;
	int32_t crop_left;
	int32_t crop_top;
	int32_t crop_right;
	int32_t crop_bottom;
	uint8_t *frame;
	size_t frame_cap;
};


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


static void drop_codec(AMediaCodec **codec)
{
	if (!*codec)
		return;
	AMediaCodec_stop(*codec);
	AMediaCodec_delete(*codec);
	*codec = NULL;
}


static void enc_destructor(void *arg)
{
	struct videnc_state *st = arg;

	drop_codec(&st->codec);
	mem_deref(st->out);
}


static int open_encoder(struct videnc_state *st, unsigned width,
			unsigned height)
{
	AMediaFormat *format;
	media_status_t status;

	drop_codec(&st->codec);
	st->config_len = 0;

	st->codec = AMediaCodec_createEncoderByType(mime);
	if (!st->codec)
		return ENODEV;

	format = AMediaFormat_new();
	AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, mime);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, (int32_t)width);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, (int32_t)height);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT,
			      COLOR_FLEXIBLE);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_BIT_RATE,
			      (int32_t)st->prm.bitrate);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_FRAME_RATE,
			      st->prm.fps > 0 ? (int32_t)(st->prm.fps + 0.5)
					      : 30);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_I_FRAME_INTERVAL,
			      KEYFRAME_INTERVAL_S);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_PROFILE,
			      PROFILE_BASELINE);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_LEVEL, LEVEL_31);

	status = AMediaCodec_configure(st->codec, format, NULL, NULL,
				       AMEDIACODEC_CONFIGURE_FLAG_ENCODE);
	AMediaFormat_delete(format);
	if (status != AMEDIA_OK) {
		warning("mediacodec: cannot configure the encoder for "
			"%ux%u (%d)\n",
			width, height, (int)status);
		drop_codec(&st->codec);
		return ENODEV;
	}

	format = AMediaCodec_getInputFormat(st->codec);
	st->color = COLOR_SEMIPLANAR;
	st->stride = (int32_t)width;
	st->slice = (int32_t)height;
	if (format) {
		AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT,
				      &st->color);
		AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_STRIDE,
				      &st->stride);
		AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_SLICE_HEIGHT,
				      &st->slice);
		AMediaFormat_delete(format);
	}
	if (st->stride < (int32_t)width)
		st->stride = (int32_t)width;
	if (st->slice < (int32_t)height)
		st->slice = (int32_t)height;

	if (AMediaCodec_start(st->codec) != AMEDIA_OK) {
		drop_codec(&st->codec);
		return ENODEV;
	}

	st->width = width;
	st->height = height;
	info("mediacodec: H.264 encoder %ux%u, %u bit/s, color %d\n", width,
	     height, st->prm.bitrate, (int)st->color);

	return 0;
}


static int encode_update(struct videnc_state **vesp, const struct vidcodec *vc,
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
		if (st->codec) {
			AMediaFormat *params = AMediaFormat_new();
			AMediaFormat_setInt32(params, "video-bitrate",
					      (int32_t)prm->bitrate);
			AMediaCodec_setParameters(st->codec, params);
			AMediaFormat_delete(params);
		}
		return 0;
	}

	st = mem_zalloc(sizeof(*st), enc_destructor);
	if (!st)
		return ENOMEM;

	st->prm = *prm;
	st->pkth = pkth;
	st->vid = vid;
	st->out = mbuf_alloc(64 * 1024);
	if (!st->out) {
		mem_deref(st);
		return ENOMEM;
	}

	*vesp = st;
	return 0;
}


static void copy_plane(uint8_t *dst, int32_t dst_stride, const uint8_t *src,
		       unsigned src_stride, unsigned width, unsigned height)
{
	for (unsigned y = 0; y < height; y++)
		memcpy(dst + (size_t)y * dst_stride,
		       src + (size_t)y * src_stride, width);
}


static bool buffer_info_fits(const AMediaCodecBufferInfo *info, size_t size)
{
	return info->offset >= 0 && info->size > 0 &&
	       (size_t)info->offset <= size &&
	       (size_t)info->size <= size - (size_t)info->offset;
}


static int fill_input(const struct videnc_state *st, uint8_t *buf, size_t size,
		      const struct vidframe *frame)
{
	const unsigned w = frame->size.w, h = frame->size.h;
	const unsigned cw = (w + 1) / 2, ch = (h + 1) / 2;
	const size_t luma = (size_t)st->stride * st->slice;
	uint8_t *chroma = buf + luma;

	if (!w || !h || w > (unsigned)st->stride || h > (unsigned)st->slice ||
	    luma + (size_t)st->stride * ch > size ||
	    bsk_yuv420_extent((uint32_t)st->stride, (uint32_t)st->slice,
			      st->color == COLOR_PLANAR, 0, 0, w, h) > size)
		return ENOMEM;

	copy_plane(buf, st->stride, frame->data[0], frame->linesize[0], w, h);

	if (st->color == COLOR_PLANAR) {
		const int32_t cstride = st->stride / 2;
		uint8_t *u = chroma;
		uint8_t *v = chroma + (size_t)cstride * (st->slice / 2);

		if (frame->fmt == VID_FMT_YUV420P) {
			copy_plane(u, cstride, frame->data[1],
				   frame->linesize[1], cw, ch);
			copy_plane(v, cstride, frame->data[2],
				   frame->linesize[2], cw, ch);
			return 0;
		}
		for (unsigned y = 0; y < ch; y++) {
			const uint8_t *uv =
				frame->data[1] + (size_t)y * frame->linesize[1];
			for (unsigned x = 0; x < cw; x++) {
				u[(size_t)y * cstride + x] = uv[2 * x];
				v[(size_t)y * cstride + x] = uv[2 * x + 1];
			}
		}
		return 0;
	}

	if (frame->fmt == VID_FMT_NV12) {
		copy_plane(chroma, st->stride, frame->data[1],
			   frame->linesize[1], 2 * cw, ch);
		return 0;
	}
	for (unsigned y = 0; y < ch; y++) {
		const uint8_t *u =
			frame->data[1] + (size_t)y * frame->linesize[1];
		const uint8_t *v =
			frame->data[2] + (size_t)y * frame->linesize[2];
		uint8_t *uv = chroma + (size_t)y * st->stride;
		for (unsigned x = 0; x < cw; x++) {
			uv[2 * x] = u[x];
			uv[2 * x + 1] = v[x];
		}
	}

	return 0;
}


static bool has_nal(const uint8_t *buf, size_t len, unsigned type)
{
	for (size_t i = 0; i + 3 < len; i++) {
		if (buf[i] == 0 && buf[i + 1] == 0 && buf[i + 2] == 1 &&
		    (buf[i + 3] & 0x1f) == type)
			return true;
	}
	return false;
}


static int drain_encoder(struct videnc_state *st, int64_t timeout_us)
{
	AMediaCodecBufferInfo info;
	int err = 0;

	for (;;) {
		ssize_t idx = AMediaCodec_dequeueOutputBuffer(st->codec, &info,
							      timeout_us);
		size_t size;
		uint8_t *buf;

		timeout_us = 0;
		if (idx < 0)
			break;

		buf = AMediaCodec_getOutputBuffer(st->codec, (size_t)idx,
						  &size);
		if (buf && buffer_info_fits(&info, size)) {
			const uint8_t *data = buf + info.offset;
			const size_t len = (size_t)info.size;

			if (info.flags & AMEDIACODEC_BUFFER_FLAG_CODEC_CONFIG) {
				if (len <= sizeof(st->config)) {
					memcpy(st->config, data, len);
					st->config_len = len;
				}
			} else if (!err) {
				uint64_t rtp_ts;

				mbuf_rewind(st->out);
				if (has_nal(data, len, 5) &&
				    !has_nal(data, len, 7) && st->config_len)
					err = mbuf_write_mem(st->out,
							     st->config,
							     st->config_len);
				err |= mbuf_write_mem(st->out, data, len);
				rtp_ts = video_calc_rtp_timestamp_fix(
					(uint64_t)info.presentationTimeUs);
				if (!err)
					err = h264_packetize(
						rtp_ts, st->out->buf,
						st->out->end, st->prm.pktsize,
						(h264_packet_h *)st->pkth,
						(void *)st->vid);
			}
		}
		AMediaCodec_releaseOutputBuffer(st->codec, (size_t)idx, false);
	}

	return err;
}


static int encode(struct videnc_state *st, bool update,
		  const struct vidframe *frame, uint64_t timestamp)
{
	ssize_t idx;
	size_t size;
	uint8_t *buf;
	int err;

	if (!st || !frame)
		return EINVAL;

	if (frame->fmt != VID_FMT_YUV420P && frame->fmt != VID_FMT_NV12)
		return ENOTSUP;

	if (!st->codec || st->width != frame->size.w ||
	    st->height != frame->size.h) {
		err = open_encoder(st, frame->size.w, frame->size.h);
		if (err)
			return err;
		update = false;
	}

	if (update) {
		AMediaFormat *params = AMediaFormat_new();
		AMediaFormat_setInt32(params, "request-sync", 0);
		AMediaCodec_setParameters(st->codec, params);
		AMediaFormat_delete(params);
	}

	idx = AMediaCodec_dequeueInputBuffer(st->codec, DEQUEUE_INPUT_US);
	if (idx >= 0) {
		size_t queued;

		buf = AMediaCodec_getInputBuffer(st->codec, (size_t)idx, &size);
		err = buf ? fill_input(st, buf, size, frame) : EIO;
		queued = (size_t)st->stride * st->slice * 3 / 2;
		if (err)
			queued = 0;
		else if (queued > size)
			queued = size;
		AMediaCodec_queueInputBuffer(st->codec, (size_t)idx, 0, queued,
					     timestamp, 0);
		if (err)
			return err;
	}

	return drain_encoder(st, DEQUEUE_OUTPUT_US);
}


static void dec_destructor(void *arg)
{
	struct viddec_state *st = arg;

	drop_codec(&st->codec);
	bsk_h264_depack_close(&st->depack);
	mem_deref(st->frame);
}


static int decode_update(struct viddec_state **vdsp, const struct vidcodec *vc,
			 const char *fmtp, const struct video *vid)
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

	if (bsk_h264_depack_init(&st->depack)) {
		mem_deref(st);
		return ENOMEM;
	}

	*vdsp = st;
	return 0;
}


static bool store_param_set(uint8_t *stored, size_t *stored_len,
			    const uint8_t *nal, size_t len)
{
	if (!nal || !len || len > BSK_H264_MAX_PARAM_SET)
		return false;
	if (*stored_len == len && 0 == memcmp(stored, nal, len))
		return false;
	memcpy(stored, nal, len);
	*stored_len = len;
	return true;
}


static void set_csd(AMediaFormat *format, const char *key, const uint8_t *nal,
		    size_t len)
{
	uint8_t buf[sizeof(startcode) + BSK_H264_MAX_PARAM_SET];

	memcpy(buf, startcode, sizeof(startcode));
	memcpy(buf + sizeof(startcode), nal, len);
	AMediaFormat_setBuffer(format, key, buf, sizeof(startcode) + len);
}


static int open_decoder(struct viddec_state *st)
{
	AMediaFormat *format;
	media_status_t status;

	drop_codec(&st->codec);

	st->codec = AMediaCodec_createDecoderByType(mime);
	if (!st->codec)
		return ENODEV;

	format = AMediaFormat_new();
	AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, mime);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, 640);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, 480);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT,
			      COLOR_FLEXIBLE);
	AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_MAX_INPUT_SIZE,
			      BSK_H264_MAX_UNIT);
	set_csd(format, AMEDIAFORMAT_KEY_CSD_0, st->sps, st->sps_len);
	set_csd(format, AMEDIAFORMAT_KEY_CSD_1, st->pps, st->pps_len);

	status = AMediaCodec_configure(st->codec, format, NULL, NULL, 0);
	AMediaFormat_delete(format);
	if (status != AMEDIA_OK || AMediaCodec_start(st->codec) != AMEDIA_OK) {
		warning("mediacodec: cannot open the H.264 decoder (%d)\n",
			(int)status);
		drop_codec(&st->codec);
		return ENODEV;
	}

	st->width = 0;
	st->height = 0;
	st->got_keyframe = false;

	return 0;
}


static void read_output_format(struct viddec_state *st)
{
	AMediaFormat *format = AMediaCodec_getOutputFormat(st->codec);

	if (!format)
		return;

	AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_WIDTH, &st->width);
	AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_HEIGHT, &st->height);
	st->stride = st->width;
	st->slice = st->height;
	st->color = COLOR_PLANAR;
	AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_STRIDE, &st->stride);
	AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_SLICE_HEIGHT,
			      &st->slice);
	AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT,
			      &st->color);
	st->crop_left = 0;
	st->crop_top = 0;
	st->crop_right = st->width - 1;
	st->crop_bottom = st->height - 1;
	AMediaFormat_getRect(format, AMEDIAFORMAT_KEY_DISPLAY_CROP,
			     &st->crop_left, &st->crop_top, &st->crop_right,
			     &st->crop_bottom);
	AMediaFormat_delete(format);

	if (st->width <= 0 || st->height <= 0) {
		st->width = 0;
		st->height = 0;
	}
	if (st->stride < st->width)
		st->stride = st->width;
	if (st->slice < st->height)
		st->slice = st->height;
	if (!bsk_crop_valid(st->width, st->height, st->crop_left, st->crop_top,
			    st->crop_right, st->crop_bottom)) {
		st->crop_left = 0;
		st->crop_top = 0;
		st->crop_right = st->width - 1;
		st->crop_bottom = st->height - 1;
	}
}


static bool output_fits(const struct viddec_state *st, size_t size, unsigned w,
			unsigned h)
{
	const uint64_t luma = (uint64_t)st->stride * (uint64_t)st->slice;
	const uint64_t end = bsk_yuv420_extent(
		(uint32_t)st->stride, (uint32_t)st->slice,
		st->color == COLOR_PLANAR, (uint32_t)st->crop_left,
		(uint32_t)st->crop_top, w, h);

	return end && end <= size && luma + luma / 2 <= size;
}


static int take_output(struct viddec_state *st, const uint8_t *buf, size_t size,
		       struct vidframe *frame)
{
	const unsigned w = (unsigned)(st->crop_right - st->crop_left + 1);
	const unsigned h = (unsigned)(st->crop_bottom - st->crop_top + 1);
	const size_t luma = (size_t)st->stride * st->slice;
	const size_t need = (size_t)bsk_yuv420_packed_size(w, h);
	const bool planar = st->color == COLOR_PLANAR;

	if (w == 0 || h == 0 || w > 4096 || h > 4096 ||
	    !output_fits(st, size, w, h))
		return EBADMSG;

	if (st->frame_cap < need) {
		mem_deref(st->frame);
		st->frame = mem_alloc(need, NULL);
		st->frame_cap = st->frame ? need : 0;
		if (!st->frame)
			return ENOMEM;
	}

	const uint8_t *y =
		buf + (size_t)st->crop_top * st->stride + st->crop_left;
	copy_plane(st->frame, (int32_t)w, y, (unsigned)st->stride, w, h);

	memset(frame, 0, sizeof(*frame));
	frame->size.w = w;
	frame->size.h = h;
	frame->data[0] = st->frame;
	frame->linesize[0] = (uint16_t)w;

	if (planar) {
		const unsigned cw = (w + 1) / 2, ch = (h + 1) / 2;
		const unsigned cs = (unsigned)st->stride / 2;
		const uint8_t *u = buf + luma +
				   (size_t)(st->crop_top / 2) * cs +
				   st->crop_left / 2;
		const uint8_t *v = buf + luma + (size_t)cs * (st->slice / 2) +
				   (size_t)(st->crop_top / 2) * cs +
				   st->crop_left / 2;
		uint8_t *du = st->frame + (size_t)w * h;
		uint8_t *dv = du + (size_t)cw * ch;

		copy_plane(du, (int32_t)cw, u, cs, cw, ch);
		copy_plane(dv, (int32_t)cw, v, cs, cw, ch);
		frame->fmt = VID_FMT_YUV420P;
		frame->data[1] = du;
		frame->data[2] = dv;
		frame->linesize[1] = (uint16_t)cw;
		frame->linesize[2] = (uint16_t)cw;
	} else {
		const unsigned ch = (h + 1) / 2;
		const unsigned cw2 = ((w + 1) / 2) * 2;
		const uint8_t *uv = buf + luma +
				    (size_t)(st->crop_top / 2) * st->stride +
				    (st->crop_left & ~1);
		uint8_t *duv = st->frame + (size_t)w * h;

		copy_plane(duv, (int32_t)cw2, uv, (unsigned)st->stride, cw2,
			   ch);
		frame->fmt = VID_FMT_NV12;
		frame->data[1] = duv;
		frame->linesize[1] = (uint16_t)cw2;
	}

	return 0;
}


static int drain_decoder(struct viddec_state *st, struct vidframe *frame)
{
	AMediaCodecBufferInfo info;
	int64_t timeout = DEQUEUE_OUTPUT_US;
	int err = 0;

	for (;;) {
		ssize_t idx = AMediaCodec_dequeueOutputBuffer(st->codec, &info,
							      timeout);
		timeout = 0;
		if (idx == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
			read_output_format(st);
			continue;
		}
		if (idx == AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED)
			continue;
		if (idx < 0)
			break;

		if (!st->width)
			read_output_format(st);

		size_t size;
		uint8_t *buf = AMediaCodec_getOutputBuffer(st->codec,
							   (size_t)idx, &size);
		if (buf && buffer_info_fits(&info, size))
			err = take_output(st, buf + info.offset,
					  (size_t)info.size, frame);
		AMediaCodec_releaseOutputBuffer(st->codec, (size_t)idx, false);
	}

	return err;
}


static int decode_access_unit(struct viddec_state *st, struct vidframe *frame,
			      bool *intra)
{
	const struct mbuf *unit_mb = st->depack.mb;
	struct bsk_h264_unit unit;
	struct mbuf *avcc;
	bool reopen;
	ssize_t idx;
	int err;

	avcc = mbuf_alloc(unit_mb->end + 64);
	if (!avcc)
		return ENOMEM;

	err = bsk_h264_annexb_to_avcc(unit_mb->buf, unit_mb->end, avcc, &unit);
	if (err)
		goto out;

	reopen = store_param_set(st->sps, &st->sps_len, unit.sps, unit.sps_len);
	reopen |=
		store_param_set(st->pps, &st->pps_len, unit.pps, unit.pps_len);

	if ((reopen || !st->codec) && st->sps_len && st->pps_len) {
		err = open_decoder(st);
		if (err)
			goto out;
	}

	if (!st->codec || !unit.have_slice) {
		err = st->codec ? 0 : EPROTO;
		goto out;
	}

	if (!st->got_keyframe && !unit.keyframe) {
		err = EPROTO;
		goto out;
	}

	idx = AMediaCodec_dequeueInputBuffer(st->codec, DEQUEUE_INPUT_US);
	if (idx < 0) {
		err = 0;
		goto out;
	}

	size_t size;
	uint8_t *buf =
		AMediaCodec_getInputBuffer(st->codec, (size_t)idx, &size);
	if (!buf || unit_mb->end > size) {
		AMediaCodec_queueInputBuffer(st->codec, (size_t)idx, 0, 0, 0,
					     0);
		err = ENOMEM;
		goto out;
	}
	memcpy(buf, unit_mb->buf, unit_mb->end);
	AMediaCodec_queueInputBuffer(st->codec, (size_t)idx, 0, unit_mb->end, 0,
				     0);

	if (unit.keyframe) {
		*intra = true;
		st->got_keyframe = true;
	}

	err = drain_decoder(st, frame);

out:
	mem_deref(avcc);
	return err;
}


static int decode(struct viddec_state *st, struct vidframe *frame,
		  struct viddec_packet *pkt)
{
	bool complete = false;
	int err;

	if (!st || !frame || !pkt || !pkt->mb || !pkt->hdr)
		return EINVAL;

	pkt->intra = false;

	err = bsk_h264_depack_put(&st->depack, pkt->mb, pkt->hdr->seq,
				  pkt->hdr->m, &complete);
	if (err || !complete)
		return err;

	err = decode_access_unit(st, frame, &pkt->intra);
	bsk_h264_depack_reset(&st->depack);

	return err;
}


static int fmtp_enc(struct mbuf *mb, const struct sdp_format *fmt, bool offer,
		    void *arg)
{
	struct vidcodec *vc = arg;
	(void)offer;

	if (!mb || !fmt || !vc)
		return 0;

	return mbuf_printf(mb, "a=fmtp:%s %s;profile-level-id=42e01f\r\n",
			   fmt->id, vc->variant);
}


static bool fmtp_cmp(const char *lfmtp, const char *rfmtp, void *arg)
{
	const struct vidcodec *vc = arg;
	(void)lfmtp;

	if (!vc)
		return false;

	return packetization_mode(vc->variant) == packetization_mode(rfmtp);
}


static struct vidcodec h264_mode1 = {
	.name = "H264",
	.variant = "packetization-mode=1",
	.encupdh = encode_update,
	.ench = encode,
	.decupdh = decode_update,
	.dech = decode,
	.fmtp_ench = fmtp_enc,
	.fmtp_cmph = fmtp_cmp,
};

static struct vidcodec h264_mode0 = {
	.name = "H264",
	.variant = "packetization-mode=0",
	.encupdh = encode_update,
	.ench = encode,
	.decupdh = decode_update,
	.dech = decode,
	.fmtp_ench = fmtp_enc,
	.fmtp_cmph = fmtp_cmp,
};


int mediacodec_init(void)
{
	vidcodec_register(baresip_vidcodecl(), &h264_mode1);
	vidcodec_register(baresip_vidcodecl(), &h264_mode0);
	return 0;
}


void mediacodec_close(void)
{
	vidcodec_unregister(&h264_mode0);
	vidcodec_unregister(&h264_mode1);
}
