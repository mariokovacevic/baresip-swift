#include <string.h>
#include "bsk_internal.h"
#include "bsk_call_internal.h"


struct call_arg {
	bsk_call_id id;
	bool flag;
	uint16_t code;
	const char *str;
	uint32_t u32a;
	uint32_t u32b;
	bsk_media_direction dir;
};


static struct bsk_call_ctx *ctx_or_enoent(bsk_engine *e, bsk_call_id id,
					  int *err)
{
	struct bsk_call_ctx *c = bsk_call_find(e, id);

	if (!c || !c->call) {
		*err = ENOENT;
		return NULL;
	}

	*err = 0;
	return c;
}


static int answer_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (c->state != BSK_CALL_INCOMING && c->state != BSK_CALL_EARLY_MEDIA)
		return EALREADY;

	c->video = ca->flag;
	if (c->early_preview)
		call_set_mdir(c->call, SDP_SENDRECV,
			      ca->flag ? SDP_SENDRECV : SDP_INACTIVE);

	err = ua_answer(bsk_call_owning_ua(e, c), c->call,
			ca->flag ? VIDMODE_ON : VIDMODE_OFF);
	if (err && c->early_preview)
		call_set_mdir(c->call, SDP_RECVONLY, bsk_call_preview_vdir(c));
	else if (!err)
		c->early_preview = false;

	return err;
}


static int progress_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (c->outgoing ||
	    (c->state != BSK_CALL_INCOMING && c->state != BSK_CALL_EARLY_MEDIA))
		return EALREADY;

	return bsk_call_start_preview(e, c, ca->flag);
}


static int hangup_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	ua_hangup(bsk_call_owning_ua(e, c), c->call, ca->code, ca->str);
	return 0;
}


static int hold_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (c->local_hold == ca->flag)
		return 0;

	err = call_hold(c->call, ca->flag);
	if (err)
		return err;

	c->local_hold = ca->flag;
	bsk_call_emit_state(
		e, c, ca->flag ? BSK_CALL_PAUSING : BSK_CALL_RESUMING, NULL);

	return 0;
}


static int set_active_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);
	struct le *le;

	if (!c)
		return err;

	for (le = e->calls.head; le; le = le->next) {
		struct bsk_call_ctx *o = le->data;
		if (o == c || !o->call || o->local_hold)
			continue;
		if (o->state == BSK_CALL_CONNECTED ||
		    o->state == BSK_CALL_STREAMS_RUNNING ||
		    o->state == BSK_CALL_PAUSED_BY_REMOTE) {
			if (0 == call_hold(o->call, true)) {
				o->local_hold = true;
				bsk_call_emit_state(e, o, BSK_CALL_PAUSING,
						    NULL);
			}
		}
	}

	if (c->local_hold) {
		err = call_hold(c->call, false);
		if (err)
			return err;
		c->local_hold = false;
		bsk_call_emit_state(e, c, BSK_CALL_RESUMING, NULL);
	}

	call_set_current(ua_calls(bsk_call_owning_ua(e, c)), c->call);
	return 0;
}


static void dtmf_timer(void *arg);


static void dtmf_next(bsk_engine *e, struct bsk_call_ctx *c)
{
	char digit;

	if (!c->call || c->dtmf_pos >= c->dtmf_len) {
		c->dtmf_len = 0;
		c->dtmf_pos = 0;
		return;
	}

	digit = c->dtmf_queue[c->dtmf_pos];
	if (0 == call_send_digit(c->call, digit)) {
		bsk_event ev;
		bsk_event_init(&ev, BSK_EVENT_CALL_DTMF);
		ev.account = c->account;
		ev.call = c->id;
		ev.u.dtmf.digit = digit;
		ev.u.dtmf.via_sip_info =
			account_dtmfmode(call_account(c->call)) ==
			DTMFMODE_SIP_INFO;
		bsk_emit(e, &ev);
	}
	c->dtmf_tone_on = true;
	tmr_start(&c->tmr_dtmf, c->dtmf_duration_ms, dtmf_timer, c);
}


static void dtmf_timer(void *arg)
{
	struct bsk_call_ctx *c = arg;
	bsk_engine *e = bsk_global_engine();

	if (!e || !c->call)
		return;

	if (c->dtmf_tone_on) {
		(void)call_send_digit(c->call, KEYCODE_REL);
		c->dtmf_tone_on = false;
		c->dtmf_pos++;
		if (c->dtmf_pos < c->dtmf_len)
			tmr_start(&c->tmr_dtmf, c->dtmf_gap_ms, dtmf_timer, c);
		else {
			c->dtmf_len = 0;
			c->dtmf_pos = 0;
		}
		return;
	}

	dtmf_next(e, c);
}


static int dtmf_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);
	size_t len, i;

	if (!c)
		return err;

	len = strlen(ca->str);
	if (!len || len > BSK_MAX_DTMF)
		return EINVAL;
	for (i = 0; i < len; i++) {
		if (!strchr("0123456789*#ABCDabcd", ca->str[i]))
			return EINVAL;
	}
	if (c->dtmf_len)
		return EBUSY;

	memcpy(c->dtmf_queue, ca->str, len);
	c->dtmf_len = len;
	c->dtmf_pos = 0;
	c->dtmf_duration_ms = ca->u32a ? ca->u32a : 160;
	c->dtmf_gap_ms = ca->u32b ? ca->u32b : 80;

	dtmf_next(e, c);
	return 0;
}


static int mute_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	c->muted = ca->flag;
	audio_mute(call_audio(c->call), ca->flag);
	return 0;
}


static int audio_dir_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	call_set_audio_ldir(c->call, bsk_call_unmap_dir(ca->dir));
	err = call_modify(c->call);
	if (!err)
		bsk_call_emit_state(e, c, BSK_CALL_UPDATING, NULL);
	return err;
}


static int video_dir_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	err = call_set_video_dir(c->call, bsk_call_unmap_dir(ca->dir));
	if (!err)
		bsk_call_emit_state(e, c, BSK_CALL_UPDATING, NULL);
	return err;
}


static int camera_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (!call_video(c->call))
		return ENOSYS;

	video_vidsrc_set_device(call_video(c->call), ca->str);
	return 0;
}


static int keyframe_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (!call_video(c->call))
		return ENOSYS;

	video_req_keyframe(call_video(c->call));
	bsk_call_emit_media(e, c, BSK_MEDIA_KEYFRAME_REQUESTED, "application");
	return 0;
}


static int video_bitrate_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	c->video_max_bitrate = ca->u32a;

	if (!video_strm(call_video(c->call)))
		return 0;

	bsk_call_rate_apply(e, c, true);
	return 0;
}


static int ice_restart_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	return bsk_call_ice_restart(c);
}


static int record_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;
	if (!call_audio(c->call))
		return ENOSYS;

	if (ca->flag)
		err = bsk_record_start(call_audio(c->call), ca->str,
				       &c->recording);
	else
		err = bsk_record_stop(&c->recording);
	if (err)
		return err;

	bsk_call_emit_media(e, c,
			    ca->flag ? BSK_MEDIA_RECORDING_STARTED
				     : BSK_MEDIA_RECORDING_STOPPED,
			    NULL);
	return 0;
}


struct attended_arg {
	bsk_call_id call;
	bsk_call_id target;
};


static int attended_op(bsk_engine *e, void *arg)
{
	struct attended_arg *aa = arg;
	struct bsk_call_ctx *c = bsk_call_find(e, aa->call);
	struct bsk_call_ctx *t = bsk_call_find(e, aa->target);

	if (!c || !t || !c->call || !t->call)
		return ENOENT;
	if (c == t)
		return EINVAL;

	return call_replace_transfer(c->call, t->call);
}


static int transfer_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	return call_transfer(c->call, ca->str);
}


static int info_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	struct bsk_call_ctx *c = bsk_call_find(e, ca->id);

	if (!c)
		return ENOENT;

	bsk_call_fill_info(c, (bsk_call_info *)ca->str);
	return 0;
}


static int stats_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	struct bsk_call_ctx *c = bsk_call_find(e, ca->id);

	if (!c)
		return ENOENT;

	bsk_call_fill_stats(c, (bsk_call_statistics *)ca->str);
	return 0;
}


static bsk_status run_call(bsk_engine *engine, bsk_op_fn *fn,
			   struct call_arg *ca, bsk_error *err,
			   const char *what)
{
	int ret;

	bsk_error_clear(err);

	if (!engine || ca->id == BSK_ID_NONE)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, fn, ca);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "%s failed: %m", what, ret);

	return BSK_OK;
}


bsk_status bsk_call_answer(bsk_engine *engine, bsk_call_id call, bool video,
			   bsk_error *err)
{
	struct call_arg ca = { call, video, 0, NULL, 0, 0, 0 };
	return run_call(engine, answer_op, &ca, err, "answer");
}


bsk_status bsk_call_progress(bsk_engine *engine, bsk_call_id call,
			     bool early_video, bsk_error *err)
{
	struct call_arg ca = { call, early_video, 0, NULL, 0, 0, 0 };
	return run_call(engine, progress_op, &ca, err, "progress");
}


bsk_status bsk_call_reject(bsk_engine *engine, bsk_call_id call,
			   uint16_t sip_status, const char *reason,
			   bsk_error *err)
{
	struct call_arg ca = { call,
			       false,
			       sip_status ? sip_status : 486,
			       reason ? reason : "Busy Here",
			       0,
			       0,
			       0 };
	return run_call(engine, hangup_op, &ca, err, "reject");
}


bsk_status bsk_call_hangup(bsk_engine *engine, bsk_call_id call, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, hangup_op, &ca, err, "hangup");
}


bsk_status bsk_call_hold(bsk_engine *engine, bsk_call_id call, bool hold,
			 bsk_error *err)
{
	struct call_arg ca = { call, hold, 0, NULL, 0, 0, 0 };
	return run_call(engine, hold_op, &ca, err, hold ? "hold" : "resume");
}


bsk_status bsk_call_set_active(bsk_engine *engine, bsk_call_id call,
			       bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, set_active_op, &ca, err, "set active");
}


bsk_status bsk_call_send_dtmf(bsk_engine *engine, bsk_call_id call,
			      const char *digits, uint32_t duration_ms,
			      uint32_t gap_ms, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, digits, duration_ms, gap_ms, 0 };

	if (!str_isset(digits))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "digits required");

	return run_call(engine, dtmf_op, &ca, err, "dtmf");
}


bsk_status bsk_call_set_microphone_muted(bsk_engine *engine, bsk_call_id call,
					 bool muted, bsk_error *err)
{
	struct call_arg ca = { call, muted, 0, NULL, 0, 0, 0 };
	return run_call(engine, mute_op, &ca, err, "mute");
}


bsk_status bsk_call_set_audio_direction(bsk_engine *engine, bsk_call_id call,
					bsk_media_direction dir, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, dir };
	return run_call(engine, audio_dir_op, &ca, err, "audio direction");
}


bsk_status bsk_call_set_video_direction(bsk_engine *engine, bsk_call_id call,
					bsk_media_direction dir, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, dir };
	return run_call(engine, video_dir_op, &ca, err, "video direction");
}


bsk_status bsk_call_set_camera(bsk_engine *engine, bsk_call_id call,
			       const char *device, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, device, 0, 0, 0 };
	return run_call(engine, camera_op, &ca, err, "set camera");
}


bsk_status bsk_call_request_keyframe(bsk_engine *engine, bsk_call_id call,
				     bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, keyframe_op, &ca, err, "keyframe request");
}


bsk_status bsk_call_set_video_max_bitrate(bsk_engine *engine, bsk_call_id call,
					  uint32_t bitrate_bps, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, bitrate_bps, 0, 0 };
	return run_call(engine, video_bitrate_op, &ca, err, "video bitrate");
}


bsk_status bsk_call_restart_ice(bsk_engine *engine, bsk_call_id call,
				bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, ice_restart_op, &ca, err, "ICE restart");
}


bsk_status bsk_call_record_start(bsk_engine *engine, bsk_call_id call,
				 const char *path, bsk_error *err)
{
	struct call_arg ca = { call, true, 0, path, 0, 0, 0 };

	if (!str_isset(path)) {
		bsk_error_clear(err);
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "path required");
	}

	return run_call(engine, record_op, &ca, err, "record start");
}


bsk_status bsk_call_record_stop(bsk_engine *engine, bsk_call_id call,
				bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, record_op, &ca, err, "record stop");
}


bsk_status bsk_call_transfer_attended(bsk_engine *engine, bsk_call_id call,
				      bsk_call_id target_call, bsk_error *err)
{
	struct attended_arg aa = { call, target_call };
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, attended_op, &aa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "attended transfer failed: %m", ret);

	return BSK_OK;
}


bsk_status bsk_call_transfer(bsk_engine *engine, bsk_call_id call,
			     const char *target_uri, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, target_uri, 0, 0, 0 };

	if (!str_isset(target_uri))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "target required");

	return run_call(engine, transfer_op, &ca, err, "transfer");
}


bsk_status bsk_call_get_info(const bsk_engine *engine, bsk_call_id call,
			     bsk_call_info *out)
{
	struct call_arg ca = { call, false, 0, (const char *)out, 0, 0, 0 };
	int ret;

	if (!engine || !out)
		return BSK_ERR_INVALID_ARGUMENT;

	ret = bsk_run((bsk_engine *)engine, info_op, &ca);
	return bsk_status_from_errno(ret);
}


bsk_status bsk_call_get_statistics(const bsk_engine *engine, bsk_call_id call,
				   bsk_call_statistics *out)
{
	struct call_arg ca = { call, false, 0, (const char *)out, 0, 0, 0 };
	int ret;

	if (!engine || !out)
		return BSK_ERR_INVALID_ARGUMENT;

	ret = bsk_run((bsk_engine *)engine, stats_op, &ca);
	return bsk_status_from_errno(ret);
}


struct list_arg {
	bsk_call_id *ids;
	size_t capacity;
	size_t count;
};


static int list_op(bsk_engine *e, void *arg)
{
	struct list_arg *la = arg;
	struct le *le;

	la->count = 0;
	for (le = e->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		if (la->ids && la->count < la->capacity)
			la->ids[la->count] = c->id;
		la->count++;
	}

	return 0;
}


size_t bsk_call_list(const bsk_engine *engine, bsk_call_id *ids,
		     size_t capacity)
{
	struct list_arg la = { ids, capacity, 0 };

	if (!engine)
		return 0;

	(void)bsk_run((bsk_engine *)engine, list_op, &la);
	return la.count;
}
