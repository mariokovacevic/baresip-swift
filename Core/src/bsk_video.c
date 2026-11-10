#include <string.h>
#include "bsk_internal.h"
#ifdef BSK_HAVE_APPLE_VIDEO
#include "vidtoolbox.h"
#endif

struct vidisp_st {
	const struct vidisp *vd;
	bsk_call_id call;
	unsigned last_w;
	unsigned last_h;
};

struct bsk_vf_enc {
	struct vidfilt_enc_st st;
	const struct video *vid;
	unsigned last_w;
	unsigned last_h;
};

static struct vidisp *bsk_vidisp;
static struct vidfilt bsk_vidfilt;
static _Thread_local unsigned delivering;


static bool map_fmt(enum vidfmt fmt, bsk_pixel_format *out)
{
	switch (fmt) {
	case VID_FMT_YUV420P: *out = BSK_PIX_I420; return true;
	case VID_FMT_NV12: *out = BSK_PIX_NV12; return true;
	case VID_FMT_ARGB: *out = BSK_PIX_BGRA; return true;
	default: return false;
	}
}


static bool to_bsk_frame(const struct vidframe *vf, uint64_t timestamp,
			 bsk_video_frame *out)
{
	int i;

	memset(out, 0, sizeof(*out));
	if (!vf || !vidframe_isvalid(vf) || !map_fmt(vf->fmt, &out->format))
		return false;

	out->width = vf->size.w;
	out->height = vf->size.h;
	for (i = 0; i < 3; i++) {
		out->planes[i] = vf->data[i];
		out->strides[i] = vf->linesize[i];
	}
	out->timestamp_us = timestamp / (VIDEO_TIMEBASE / 1000000);
#ifdef BSK_HAVE_APPLE_VIDEO
	out->native_buffer = vf->fmt == VID_FMT_NV12
				     ? vidtoolbox_native_buffer(vf->data[0])
				     : NULL;
#else
	out->native_buffer = NULL;
#endif

	return true;
}


static void deliver(bsk_engine *e, bsk_call_id call, bool local,
		    const struct vidframe *vf, uint64_t timestamp,
		    unsigned *last_w, unsigned *last_h)
{
	struct bsk_video_sink sink;
	bsk_video_frame frame;
	bool have = false;

	if (!to_bsk_frame(vf, timestamp, &frame))
		return;

	mtx_lock(&e->video_mtx);
	if (call == BSK_ID_NONE) {
		sink = e->preview_sink;
		have = sink.on_frame != NULL;
	} else {
		struct bsk_call_ctx *c = bsk_call_find(e, call);
		if (c) {
			sink = local ? c->local_sink : c->remote_sink;
			have = sink.on_frame != NULL;
		}
	}
	if (have)
		e->video_inflight++;
	mtx_unlock(&e->video_mtx);

	if (!have)
		return;

	delivering++;
	if (sink.on_size &&
	    (*last_w != frame.width || *last_h != frame.height)) {
		*last_w = frame.width;
		*last_h = frame.height;
		sink.on_size(e, call, local, frame.width, frame.height,
			     sink.user);
	}

	sink.on_frame(e, call, local, &frame, sink.user);
	delivering--;

	mtx_lock(&e->video_mtx);
	e->video_inflight--;
	cnd_broadcast(&e->video_cnd);
	mtx_unlock(&e->video_mtx);
}


static void wait_for_deliveries(bsk_engine *e, unsigned own)
{
	while (e->video_inflight > own)
		cnd_wait(&e->video_cnd, &e->video_mtx);
}


void bsk_video_detach_call(bsk_engine *e, struct bsk_call_ctx *c)
{
	mtx_lock(&e->video_mtx);
	memset(&c->local_sink, 0, sizeof(c->local_sink));
	memset(&c->remote_sink, 0, sizeof(c->remote_sink));
	wait_for_deliveries(e, delivering);
	mtx_unlock(&e->video_mtx);
}


static void disp_destructor(void *arg)
{
	(void)arg;
}


static int disp_alloc(struct vidisp_st **vp, const struct vidisp *vd,
		      struct vidisp_prm *prm, const char *dev,
		      vidisp_resize_h *resizeh, void *arg)
{
	struct vidisp_st *st;
	(void)prm;
	(void)resizeh;
	(void)arg;

	if (!vp || !vd)
		return EINVAL;

	st = mem_zalloc(sizeof(*st), disp_destructor);
	if (!st)
		return ENOMEM;

	st->vd = vd;
	if (dev && 0 == strncmp(dev, "bsk:", 4))
		st->call = strtoull(dev + 4, NULL, 10);

	*vp = st;
	return 0;
}


static int disp_display(struct vidisp_st *st, const char *title,
			const struct vidframe *frame, uint64_t timestamp)
{
	bsk_engine *e = bsk_global_engine();
	(void)title;

	if (!e || !st || st->call == BSK_ID_NONE)
		return 0;

	deliver(e, st->call, false, frame, timestamp, &st->last_w, &st->last_h);
	return 0;
}


static void enc_destructor(void *arg)
{
	struct bsk_vf_enc *st = arg;

	list_unlink(&st->st.le);
}


static int enc_update(struct vidfilt_enc_st **stp, void **ctx,
		      const struct vidfilt *vf, struct vidfilt_prm *prm,
		      const struct video *vid)
{
	struct bsk_vf_enc *st;
	(void)ctx;
	(void)prm;

	if (!stp || !vf)
		return EINVAL;
	if (*stp)
		return 0;

	st = mem_zalloc(sizeof(*st), enc_destructor);
	if (!st)
		return ENOMEM;

	st->vid = vid;
	*stp = (struct vidfilt_enc_st *)st;
	return 0;
}


static int enc_frame(struct vidfilt_enc_st *vst, struct vidframe *frame,
		     uint64_t *timestamp)
{
	struct bsk_vf_enc *st = (struct bsk_vf_enc *)vst;
	bsk_engine *e = bsk_global_engine();
	bsk_call_id call = BSK_ID_NONE;
	struct le *le;

	if (!e || !st || !frame)
		return 0;

	mtx_lock(&e->video_mtx);
	for (le = e->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		if (c->call && call_video(c->call) == st->vid) {
			call = c->id;
			break;
		}
	}
	mtx_unlock(&e->video_mtx);

	if (call != BSK_ID_NONE)
		deliver(e, call, true, frame, timestamp ? *timestamp : 0,
			&st->last_w, &st->last_h);

	return 0;
}


int bsk_video_init(bsk_engine *e)
{
	int err;

#ifdef BSK_HAVE_APPLE_VIDEO
	err = vidtoolbox_init();
	if (err)
		return err;
	err = bskcapture_init();
	if (err)
		return err;
#endif

	err = vidisp_register(&bsk_vidisp, baresip_vidispl(), "bsk", disp_alloc,
			      NULL, disp_display, NULL);
	if (err)
		return err;

	memset(&bsk_vidfilt, 0, sizeof(bsk_vidfilt));
	bsk_vidfilt.name = "bsk";
	bsk_vidfilt.encupdh = enc_update;
	bsk_vidfilt.ench = enc_frame;
	vidfilt_register(baresip_vidfiltl(), &bsk_vidfilt);

	conf_config()->video.disp_mod[0] = '\0';
	str_ncpy(conf_config()->video.disp_mod, "bsk",
		 sizeof(conf_config()->video.disp_mod));
	(void)e;

	return 0;
}


void bsk_video_close(bsk_engine *e)
{
	e->preview_src = mem_deref(e->preview_src);
	mtx_lock(&e->video_mtx);
	memset(&e->preview_sink, 0, sizeof(e->preview_sink));
	wait_for_deliveries(e, 0);
	mtx_unlock(&e->video_mtx);
	vidfilt_unregister(&bsk_vidfilt);
	bsk_vidisp = mem_deref(bsk_vidisp);
#ifdef BSK_HAVE_APPLE_VIDEO
	bskcapture_close();
	vidtoolbox_close();
#endif
}


void bsk_video_bind_call(struct bsk_call_ctx *c)
{
	struct video *v = c->call ? call_video(c->call) : NULL;
	char dev[32];
	char src[128];

	if (!v)
		return;

	str_ncpy(src, video_get_src_dev(v) ? video_get_src_dev(v) : "",
		 sizeof(src));
	re_snprintf(dev, sizeof(dev), "bsk:%llu", (unsigned long long)c->id);
	video_set_devicename(v, src, dev);
}


struct sink_arg {
	bsk_call_id call;
	bool local;
	bsk_video_sink sink;
	bool has_sink;
	unsigned own;
};


static int sink_op(bsk_engine *e, void *arg)
{
	struct sink_arg *sa = arg;
	struct bsk_call_ctx *c = bsk_call_find(e, sa->call);

	if (!c)
		return ENOENT;

	mtx_lock(&e->video_mtx);
	if (sa->local)
		c->local_sink = sa->has_sink
					? sa->sink
					: (bsk_video_sink){ NULL, NULL, NULL };
	else
		c->remote_sink = sa->has_sink
					 ? sa->sink
					 : (bsk_video_sink){ NULL, NULL, NULL };
	wait_for_deliveries(e, sa->own);
	mtx_unlock(&e->video_mtx);

	return 0;
}


bsk_status bsk_call_set_video_sink(bsk_engine *engine, bsk_call_id call,
				   bool local, const bsk_video_sink *sink,
				   bsk_error *err)
{
	struct sink_arg sa;
	int ret;

	bsk_error_clear(err);

	if (!engine || call == BSK_ID_NONE)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	sa.call = call;
	sa.local = local;
	sa.has_sink = sink != NULL;
	sa.own = delivering;
	if (sink)
		sa.sink = *sink;

	ret = bsk_run(engine, sink_op, &sa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "video sink failed: %m", ret);

	return BSK_OK;
}


static void preview_frame_handler(struct vidframe *frame, uint64_t timestamp,
				  void *arg)
{
	bsk_engine *e = arg;

	deliver(e, BSK_ID_NONE, true, frame, timestamp, &e->preview_w,
		&e->preview_h);
}


static void preview_error_handler(int err, void *arg)
{
	bsk_engine *e = arg;
	char msg[96];
	int n = re_snprintf(msg, sizeof(msg), "bsk: video preview error: %m",
			    err);

	if (n > 0)
		bsk_log_emit(e, BSK_LOG_WARNING, BSK_LOG_DOMAIN_MEDIA, msg,
			     (size_t)n);
}


struct preview_arg {
	const char *device;
	bsk_video_sink sink;
	unsigned own;
};


static int preview_start_op(bsk_engine *e, void *arg)
{
	struct preview_arg *pa = arg;
	struct config *cfg = conf_config();
	struct vidsrc_prm prm;
	struct vidsz size;
	int err;

	if (!str_isset(cfg->video.src_mod))
		return ENOSYS;

	e->preview_src = mem_deref(e->preview_src);

	mtx_lock(&e->video_mtx);
	e->preview_sink = pa->sink;
	e->preview_w = 0;
	e->preview_h = 0;
	wait_for_deliveries(e, pa->own);
	mtx_unlock(&e->video_mtx);

	prm.fps = cfg->video.fps;
	prm.fmt = cfg->video.enc_fmt;
	size.w = cfg->video.width;
	size.h = cfg->video.height;

	err = vidsrc_alloc(
		&e->preview_src, baresip_vidsrcl(), cfg->video.src_mod, &prm,
		&size, NULL,
		str_isset(pa->device) ? pa->device : cfg->video.src_dev,
		preview_frame_handler, NULL, preview_error_handler, e);
	if (err) {
		mtx_lock(&e->video_mtx);
		memset(&e->preview_sink, 0, sizeof(e->preview_sink));
		wait_for_deliveries(e, pa->own);
		mtx_unlock(&e->video_mtx);
	}

	return err;
}


static int preview_stop_op(bsk_engine *e, void *arg)
{
	unsigned *own = arg;

	e->preview_src = mem_deref(e->preview_src);
	mtx_lock(&e->video_mtx);
	memset(&e->preview_sink, 0, sizeof(e->preview_sink));
	wait_for_deliveries(e, *own);
	mtx_unlock(&e->video_mtx);

	return 0;
}


bsk_status bsk_video_preview_start(bsk_engine *engine, const char *device,
				   const bsk_video_sink *sink, bsk_error *err)
{
	struct preview_arg pa;
	int ret;

	bsk_error_clear(err);

	if (!engine || !sink || !sink->on_frame)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "sink required");

	pa.device = device;
	pa.sink = *sink;
	pa.own = delivering;

	ret = bsk_run(engine, preview_start_op, &pa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "video preview failed: %m", ret);

	return BSK_OK;
}


bsk_status bsk_video_preview_stop(bsk_engine *engine, bsk_error *err)
{
	unsigned own = delivering;
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, preview_stop_op, &own);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "video preview stop failed: %m",
				     ret);

	return BSK_OK;
}


struct devices_arg {
	char *buf;
	size_t buf_len;
	size_t needed;
};


static int devices_op(bsk_engine *e, void *arg)
{
	struct devices_arg *da = arg;
	const struct vidsrc *vs;
	struct le *le;
	size_t o = 0;
	(void)e;

	da->needed = 0;
	vs = vidsrc_find(baresip_vidsrcl(), conf_config()->video.src_mod);
	if (!vs)
		return 0;

	for (le = vs->dev_list.head; le; le = le->next) {
		const struct mediadev *md = le->data;
		size_t n = strlen(md->name);

		if (da->buf && o + n + 1 < da->buf_len) {
			if (o)
				da->buf[o - 1] = '\n';
			memcpy(da->buf + o, md->name, n);
			o += n;
			da->buf[o++] = '\0';
		}
		da->needed += n + 1;
	}

	return 0;
}


size_t bsk_video_list_devices(const bsk_engine *engine, char *buf,
			      size_t buf_len)
{
	struct devices_arg da = { buf, buf_len, 0 };

	if (!engine)
		return 0;
	if (buf && buf_len)
		buf[0] = '\0';

	(void)bsk_run((bsk_engine *)engine, devices_op, &da);
	return da.needed;
}
