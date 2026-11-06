#include <string.h>
#include "bsk_internal.h"


struct bsk_call_ctx *bsk_call_find(bsk_engine *engine, bsk_call_id id)
{
	struct le *le;

	for (le = engine->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		if (c->id == id)
			return c;
	}

	return NULL;
}


struct bsk_call_ctx *bsk_call_find_call(bsk_engine *engine,
					const struct call *call)
{
	struct le *le;

	for (le = engine->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		if (c->call == call)
			return c;
	}

	return NULL;
}


static void call_ctx_destructor(void *arg)
{
	struct bsk_call_ctx *c = arg;
	bsk_engine *e = bsk_global_engine();

	tmr_cancel(&c->tmr_dtmf);
	if (e)
		mtx_lock(&e->video_mtx);
	list_unlink(&c->le);
	if (e)
		mtx_unlock(&e->video_mtx);
}


void bsk_calls_flush(bsk_engine *engine)
{
	list_flush(&engine->calls);
}


static struct bsk_call_ctx *call_ctx_alloc(bsk_engine *e, struct call *call,
					   bsk_account_id account,
					   bool outgoing)
{
	struct bsk_call_ctx *c;

	c = mem_zalloc(sizeof(*c), call_ctx_destructor);
	if (!c)
		return NULL;

	c->id = e->next_call_id++;
	c->call = call;
	c->account = account;
	c->outgoing = outgoing;
	c->state = outgoing ? BSK_CALL_OUTGOING_INIT : BSK_CALL_INCOMING;
	c->steady_state = c->state;
	c->created_ms = bsk_now_ms();
	tmr_init(&c->tmr_dtmf);
	mtx_lock(&e->video_mtx);
	list_append(&e->calls, &c->le, c);
	mtx_unlock(&e->video_mtx);
	bsk_video_bind_call(c);

	return c;
}


static void get_dirs(struct call *call, enum sdp_dir *adir,
		     enum sdp_dir *vdir)
{
	struct stream *as = audio_strm(call_audio(call));
	struct stream *vs = video_strm(call_video(call));

	*adir = as ? sdp_media_ldir(stream_sdpmedia(as)) : SDP_INACTIVE;
	*vdir = vs ? sdp_media_ldir(stream_sdpmedia(vs)) : SDP_INACTIVE;
}


static bsk_media_direction map_dir(enum sdp_dir dir)
{
	switch (dir) {
	case SDP_SENDONLY: return BSK_DIR_SENDONLY;
	case SDP_RECVONLY: return BSK_DIR_RECVONLY;
	case SDP_SENDRECV: return BSK_DIR_SENDRECV;
	default:           return BSK_DIR_INACTIVE;
	}
}


static enum sdp_dir unmap_dir(bsk_media_direction dir)
{
	switch (dir) {
	case BSK_DIR_SENDONLY: return SDP_SENDONLY;
	case BSK_DIR_RECVONLY: return SDP_RECVONLY;
	case BSK_DIR_SENDRECV: return SDP_SENDRECV;
	default:               return SDP_INACTIVE;
	}
}


static void fill_info(struct bsk_call_ctx *c, bsk_call_info *info)
{
	struct call *call = c->call;
	const struct aucodec *ac;
	const struct vidcodec *vc;
	enum sdp_dir adir = SDP_INACTIVE, vdir = SDP_INACTIVE;

	memset(info, 0, sizeof(*info));
	info->id = c->id;
	info->account = c->account;
	info->state = c->state;
	info->outgoing = c->outgoing;

	if (!call)
		return;

	info->has_video = call_has_video(call);
	get_dirs(call, &adir, &vdir);
	info->audio_dir = map_dir(adir);
	info->video_dir = map_dir(vdir);
	str_ncpy(info->sip_call_id, call_id(call) ? call_id(call) : "",
		 sizeof(info->sip_call_id));
	str_ncpy(info->remote_uri, call_peeruri(call) ? call_peeruri(call) : "",
		 sizeof(info->remote_uri));
	str_ncpy(info->remote_display_name,
		 call_peername(call) ? call_peername(call) : "",
		 sizeof(info->remote_display_name));
	ac = audio_codec(call_audio(call), true);
	if (ac)
		str_ncpy(info->audio_codec, ac->name, sizeof(info->audio_codec));
	vc = video_codec(call_video(call), true);
	if (vc)
		str_ncpy(info->video_codec, vc->name, sizeof(info->video_codec));
	info->setup_ms = call_setup_duration(call) * 1000;
	info->duration_s = call_duration(call);
}


static void emit_state(bsk_engine *e, struct bsk_call_ctx *c,
		       bsk_call_state state, const bsk_error *error)
{
	bsk_event ev;

	c->state = state;
	if (state == BSK_CALL_STREAMS_RUNNING || state == BSK_CALL_PAUSED ||
	    state == BSK_CALL_PAUSED_BY_REMOTE || state == BSK_CALL_CONNECTED)
		c->steady_state = state;

	bsk_event_init(&ev, BSK_EVENT_CALL_STATE);
	ev.account = c->account;
	ev.call = c->id;
	ev.u.call_state.state = state;
	if (error)
		ev.u.call_state.error = *error;

	bsk_emit(e, &ev);
}


static void emit_media(bsk_engine *e, struct bsk_call_ctx *c,
		       bsk_media_event me, const char *detail)
{
	bsk_event ev;
	enum sdp_dir adir = SDP_INACTIVE, vdir = SDP_INACTIVE;

	bsk_event_init(&ev, BSK_EVENT_CALL_MEDIA);
	ev.account = c->account;
	ev.call = c->id;
	ev.u.media.event = me;
	if (c->call) {
		get_dirs(c->call, &adir, &vdir);
		ev.u.media.audio_dir = map_dir(adir);
		ev.u.media.video_dir = map_dir(vdir);
	}
	if (detail)
		str_ncpy(ev.u.media.detail, detail, sizeof(ev.u.media.detail));

	bsk_emit(e, &ev);
}


static void apply_audio_activation(bsk_engine *e, struct bsk_call_ctx *c)
{
	struct audio *au = c->call ? call_audio(c->call) : NULL;

	if (!au || !audio_started(au))
		return;

	if (e->audio_active) {
		(void)audio_set_source(au, e->audio_src_mod, e->audio_src_dev);
		(void)audio_set_player(au, e->audio_play_mod, e->audio_play_dev);
		if (c->muted)
			audio_mute(au, true);
	}
	else {
		(void)audio_set_source(au, NULL, NULL);
		(void)audio_set_player(au, NULL, NULL);
	}
}


static bool call_uses_ice(const struct bsk_call_ctx *c)
{
	const char *mnat;

	if (!c->call)
		return false;

	mnat = account_medianat(call_account(c->call));

	return mnat && 0 == str_casecmp(mnat, "ice");
}


static int restart_ice(struct bsk_call_ctx *c)
{
	int err;

	if (!call_uses_ice(c))
		return ENOSYS;

	if (!call_refresh_allowed(c->call))
		return EBUSY;

	err = call_restart_mnat(c->call);
	if (err == ENOTSUP)
		return EALREADY;

	return err;
}


static uint32_t video_cap(const bsk_engine *e, const struct bsk_call_ctx *c)
{
	if (c->video_max_bitrate && c->video_max_bitrate < e->video_bitrate)
		return c->video_max_bitrate;

	return e->video_bitrate;
}


static void rate_apply(bsk_engine *e, struct bsk_call_ctx *c, bool force)
{
	struct video *v = call_video(c->call);
	struct stream *vs = video_strm(v);
	const struct rtcp_stats *rs;
	uint32_t cap, target;

	if (!vs || !video_bitrate(v))
		return;

	cap = video_cap(e, c);

	if (!c->rate_init) {
		bsk_rate_init(&c->rate, video_bitrate(v), e->video_min_bitrate,
			      cap, bsk_now_ms());
		c->rate_init = true;
	}

	bsk_rate_set_max(&c->rate, cap);

	if (!e->video_adaptive) {
		c->rate.current = cap;
	}
	else if (!force) {
		rs = stream_rtcp_stats(vs);
		if (rs)
			(void)bsk_rate_update(&c->rate, rs->tx.sent,
					      rs->tx.lost, bsk_now_ms());
	}

	target = c->rate.current;
	if (target && target != video_bitrate(v))
		(void)video_set_bitrate(v, target);
}


void bsk_calls_rate_tick(bsk_engine *engine)
{
	struct le *le;

	for (le = engine->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;

		if (!c->call)
			continue;
		if (!engine->video_adaptive && !c->video_max_bitrate)
			continue;

		rate_apply(engine, c, false);
	}
}


void bsk_calls_audio_changed(bsk_engine *engine)
{
	struct le *le;

	for (le = engine->calls.head; le; le = le->next)
		apply_audio_activation(engine, le->data);
}


static void fill_stats(struct bsk_call_ctx *c, bsk_call_statistics *st)
{
	struct stream *as, *vs;
	const struct rtcp_stats *rs;
	struct jbuf_stat js;

	memset(st, 0, sizeof(*st));
	st->id = c->id;

	if (!c->call)
		return;

	as = audio_strm(call_audio(c->call));
	vs = video_strm(call_video(c->call));

	if (as) {
		st->audio.tx_packets = stream_metric_get_tx_n_packets(as);
		st->audio.rx_packets = stream_metric_get_rx_n_packets(as);
		st->audio.tx_bytes = stream_metric_get_tx_n_bytes(as);
		st->audio.rx_bytes = stream_metric_get_rx_n_bytes(as);
		st->audio.tx_bitrate_bps = stream_metric_get_tx_bitrate(as);
		st->audio.rx_bitrate_bps = stream_metric_get_rx_bitrate(as);
		st->audio.secure = stream_is_secure(as);
		rs = stream_rtcp_stats(as);
		if (rs) {
			st->audio.rx_lost = rs->rx.lost;
			st->audio.rx_jitter_ms = rs->rx.jit / 1000;
			st->audio.rtt_ms = rs->rtt / 1000;
			if (rs->rx.sent + (uint32_t)rs->rx.lost)
				st->audio.rx_fraction_lost_permille =
					(uint32_t)((uint64_t)rs->rx.lost * 1000 /
						   (rs->rx.sent + rs->rx.lost));
		}
		if (0 == stream_jbuf_stats(as, &js))
			st->audio.jitter_buffer_delay_ms = js.c_delay;
	}

	if (vs) {
		st->video.tx_packets = stream_metric_get_tx_n_packets(vs);
		st->video.rx_packets = stream_metric_get_rx_n_packets(vs);
		st->video.tx_bytes = stream_metric_get_tx_n_bytes(vs);
		st->video.rx_bytes = stream_metric_get_rx_n_bytes(vs);
		st->video.tx_bitrate_bps = stream_metric_get_tx_bitrate(vs);
		st->video.rx_bitrate_bps = stream_metric_get_rx_bitrate(vs);
		st->video.secure = stream_is_secure(vs);
		st->video_target_bitrate_bps =
			video_bitrate(call_video(c->call));
		rs = stream_rtcp_stats(vs);
		if (rs) {
			st->video.rx_lost = rs->rx.lost;
			st->video.rx_jitter_ms = rs->rx.jit / 1000;
			st->video.rtt_ms = rs->rtt / 1000;
		}
	}

	st->ice_state = c->ice_state;
	st->local_candidate = c->ice_local_type;
	st->remote_candidate = c->ice_remote_type;
	str_ncpy(st->local_address, c->ice_local_addr, sizeof(st->local_address));
	str_ncpy(st->remote_address, c->ice_remote_addr,
		 sizeof(st->remote_address));

	{
		double loss = st->audio.rx_fraction_lost_permille / 10.0;
		double delay = st->audio.rtt_ms / 2.0 +
			st->audio.jitter_buffer_delay_ms + 20.0;
		double r = 93.2;
		if (delay > 160.0)
			r -= 0.024 * delay + 0.11 * (delay - 177.3);
		else
			r -= 0.024 * delay;
		r -= 11.0 + 40.0 * loss / (loss + 10.0);
		if (r < 0)
			r = 0;
		if (r > 100)
			r = 100;
		st->mos_estimate = (float)(1.0 + 0.035 * r +
					   r * (r - 60.0) * (100.0 - r) *
					   7.0e-6);
	}
}


static void finish_call(bsk_engine *e, struct bsk_call_ctx *c,
			struct bevent *event)
{
	const char *text = bevent_get_text(event);
	uint16_t scode = c->call ? call_scode(c->call) : 0;
	bsk_error error;
	bool failed;

	failed = (c->state == BSK_CALL_OUTGOING_INIT ||
		  c->state == BSK_CALL_OUTGOING_RINGING ||
		  c->state == BSK_CALL_EARLY_MEDIA) &&
		 (scode >= 300 || (scode == 0 && str_isset(text)));

	bsk_error_set(&error, scode >= 300 ? BSK_ERR_SIP :
		      (failed ? BSK_ERR_NETWORK : BSK_OK), 0, scode,
		      NULL, "%s", text ? text : "");

	emit_state(e, c, failed ? BSK_CALL_FAILED : BSK_CALL_ENDED, &error);
	c->call = NULL;
	emit_state(e, c, BSK_CALL_RELEASED, NULL);
	mem_deref(c);
}


void bsk_call_handle_event(bsk_engine *e, enum bevent_ev ev,
			   struct bevent *event)
{
	struct call *call = bevent_get_call(event);
	struct bsk_call_ctx *c = bsk_call_find_call(e, call);
	const char *text = bevent_get_text(event);

	if (ev == BEVENT_CALL_INCOMING && !c) {
		struct bsk_account_ctx *a =
			bsk_account_find_ua(e, bevent_get_ua(event));
		bsk_event bev;

		c = call_ctx_alloc(e, call, a ? a->id : BSK_ID_NONE, false);
		if (!c)
			return;
		c->video = call_has_video(call);

		bsk_event_init(&bev, BSK_EVENT_CALL_INCOMING);
		bev.account = c->account;
		bev.call = c->id;
		fill_info(c, &bev.u.call_incoming.info);
		bev.u.call_incoming.early_video =
			call_early_video_available(call);
		bsk_emit(e, &bev);
		return;
	}

	if (!c)
		return;

	switch (ev) {

	case BEVENT_CALL_OUTGOING:
		emit_state(e, c, BSK_CALL_OUTGOING_INIT, NULL);
		break;

	case BEVENT_CALL_RINGING:
		emit_state(e, c, BSK_CALL_OUTGOING_RINGING, NULL);
		break;

	case BEVENT_CALL_PROGRESS:
		emit_state(e, c, BSK_CALL_EARLY_MEDIA, NULL);
		if (call_early_video_available(call))
			emit_media(e, c, BSK_MEDIA_EARLY_VIDEO_AVAILABLE, NULL);
		break;

	case BEVENT_CALL_ANSWERED:
	case BEVENT_CALL_ESTABLISHED:
		if (c->state != BSK_CALL_CONNECTED &&
		    c->state != BSK_CALL_STREAMS_RUNNING)
			emit_state(e, c, BSK_CALL_CONNECTED, NULL);
		if (c->rtp_established && c->state == BSK_CALL_CONNECTED)
			emit_state(e, c, BSK_CALL_STREAMS_RUNNING, NULL);
		apply_audio_activation(e, c);
		break;

	case BEVENT_CALL_RTPESTAB:
		c->rtp_established = true;
		emit_media(e, c, BSK_MEDIA_AUDIO_STARTED, text);
		if (c->state == BSK_CALL_CONNECTED)
			emit_state(e, c, BSK_CALL_STREAMS_RUNNING, NULL);
		break;

	case BEVENT_CALL_HOLD:
		c->remote_hold = true;
		emit_media(e, c, BSK_MEDIA_REMOTE_HOLD, NULL);
		if (!c->local_hold)
			emit_state(e, c, BSK_CALL_PAUSED_BY_REMOTE, NULL);
		break;

	case BEVENT_CALL_RESUME:
		c->remote_hold = false;
		emit_media(e, c, BSK_MEDIA_REMOTE_RESUME, NULL);
		if (!c->local_hold) {
			emit_state(e, c, BSK_CALL_STREAMS_RUNNING, NULL);
			if (call_has_video(call)) {
				video_req_keyframe(call_video(call));
				emit_media(e, c, BSK_MEDIA_KEYFRAME_REQUESTED,
					   "remote resume");
			}
		}
		break;

	case BEVENT_CALL_REMOTE_SDP:
		if (text && 0 == str_casecmp(text, "answer")) {
			if (c->state == BSK_CALL_PAUSING)
				emit_state(e, c, BSK_CALL_PAUSED, NULL);
			else if (c->state == BSK_CALL_RESUMING) {
				emit_state(e, c, BSK_CALL_STREAMS_RUNNING, NULL);
				if (call_has_video(call)) {
					video_req_keyframe(call_video(call));
					emit_media(e, c,
						   BSK_MEDIA_KEYFRAME_REQUESTED,
						   "local resume");
				}
			}
			else if (c->state == BSK_CALL_UPDATING)
				emit_state(e, c, c->steady_state, NULL);
		}
		break;

	case BEVENT_CALL_DTMF_START:
	case BEVENT_CALL_DTMF_END: {
		bsk_event dev;
		bsk_event_init(&dev, BSK_EVENT_CALL_DTMF);
		dev.account = c->account;
		dev.call = c->id;
		dev.u.dtmf.digit = text ? text[0] : 0;
		dev.u.dtmf.end = (ev == BEVENT_CALL_DTMF_END);
		bsk_emit(e, &dev);
		break;
	}

	case BEVENT_CALL_MENC:
		emit_media(e, c, BSK_MEDIA_ENCRYPTION_ESTABLISHED, text);
		break;

	case BEVENT_CALL_TRANSFER:
	case BEVENT_CALL_TRANSFER_FAILED: {
		bsk_event tev;
		bsk_event_init(&tev, BSK_EVENT_CALL_TRANSFER);
		tev.account = c->account;
		tev.call = c->id;
		tev.u.transfer.failed = (ev == BEVENT_CALL_TRANSFER_FAILED);
		if (text)
			str_ncpy(tev.u.transfer.target_uri, text,
				 sizeof(tev.u.transfer.target_uri));
		bsk_emit(e, &tev);
		break;
	}

	case BEVENT_CALL_RTCP: {
		bsk_event sev;
		bsk_event_init(&sev, BSK_EVENT_CALL_STATISTICS);
		sev.account = c->account;
		sev.call = c->id;
		fill_stats(c, &sev.u.statistics.stats);
		bsk_emit(e, &sev);
		break;
	}

	case BEVENT_AUDIO_ERROR: {
		bsk_event aev;
		bsk_event_init(&aev, BSK_EVENT_AUDIO);
		aev.account = c->account;
		aev.call = c->id;
		bsk_error_set(&aev.u.audio.error, BSK_ERR_MEDIA, 0, 0, NULL,
			      "%s", text ? text : "audio error");
		bsk_emit(e, &aev);
		break;
	}

	case BEVENT_CALL_CLOSED:
		finish_call(e, c, event);
		break;

	default:
		break;
	}
}


static bsk_candidate_type cand_type_from_name(const struct pl *name)
{
	if (0 == pl_strcasecmp(name, "srflx"))
		return BSK_CAND_SRFLX;
	if (0 == pl_strcasecmp(name, "prflx"))
		return BSK_CAND_PRFLX;
	if (0 == pl_strcasecmp(name, "relay"))
		return BSK_CAND_RELAY;
	return BSK_CAND_HOST;
}


static struct bsk_call_ctx *find_by_sdpm(bsk_engine *e, const void *sdpm)
{
	struct le *le;

	for (le = e->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		struct stream *as, *vs;

		if (!c->call)
			continue;
		as = audio_strm(call_audio(c->call));
		vs = video_strm(call_video(c->call));
		if ((as && stream_sdpmedia(as) == sdpm) ||
		    (vs && stream_sdpmedia(vs) == sdpm))
			return c;
	}

	return NULL;
}


bool bsk_ice_parse_event(const char *text, size_t len,
			 struct bsk_ice_info *out)
{
	struct pl module, event, rest, val;

	if (!text || !out || !len)
		return false;

	memset(out, 0, sizeof(*out));

	if (re_regex(text, len, "[^,]+,[^,]+,[^]*", &module, &event, &rest))
		return false;
	if (0 != pl_strcasecmp(&module, "ice"))
		return false;

	if (0 == re_regex(rest.p, rest.l, "sdpm=0x[0-9a-fA-F]+", &val))
		out->sdpm = (void *)(uintptr_t)pl_x64(&val);
	else if (0 == re_regex(rest.p, rest.l, "sdpm=[0-9a-fA-F]+", &val))
		out->sdpm = (void *)(uintptr_t)pl_x64(&val);
	else
		return false;

	if (0 == pl_strcasecmp(&event, "gathering"))
		out->state = BSK_ICE_GATHERING;
	else if (0 == pl_strcasecmp(&event, "checking"))
		out->state = BSK_ICE_CHECKING;
	else if (0 == pl_strcasecmp(&event, "failed"))
		out->state = BSK_ICE_FAILED;
	else if (0 == pl_strcasecmp(&event, "connected")) {
		out->state = BSK_ICE_CONNECTED;
		if (0 == re_regex(rest.p, rest.l, "ltype=[a-z]+", &val))
			out->local_type = cand_type_from_name(&val);
		if (0 == re_regex(rest.p, rest.l, "rtype=[a-z]+", &val))
			out->remote_type = cand_type_from_name(&val);
		if (0 == re_regex(rest.p, rest.l, "laddr=[^ ]+", &val))
			(void)pl_strcpy(&val, out->local_addr,
					sizeof(out->local_addr));
		if (0 == re_regex(rest.p, rest.l, "raddr=[^ ]+", &val))
			(void)pl_strcpy(&val, out->remote_addr,
					sizeof(out->remote_addr));
	}
	else
		return false;

	return true;
}


void bsk_call_handle_module_event(bsk_engine *e, const char *text)
{
	struct bsk_ice_info info;
	struct bsk_call_ctx *c;
	bsk_event ev;

	if (!text || !bsk_ice_parse_event(text, strlen(text), &info))
		return;

	c = find_by_sdpm(e, info.sdpm);
	if (!c)
		return;

	c->ice_state = info.state;
	if (info.state == BSK_ICE_CONNECTED) {
		c->ice_local_type = info.local_type;
		c->ice_remote_type = info.remote_type;
		str_ncpy(c->ice_local_addr, info.local_addr,
			 sizeof(c->ice_local_addr));
		str_ncpy(c->ice_remote_addr, info.remote_addr,
			 sizeof(c->ice_remote_addr));
	}

	bsk_event_init(&ev, BSK_EVENT_ICE);
	ev.account = c->account;
	ev.call = c->id;
	ev.u.ice.state = c->ice_state;
	ev.u.ice.local_candidate = c->ice_local_type;
	ev.u.ice.remote_candidate = c->ice_remote_type;
	str_ncpy(ev.u.ice.local_address, c->ice_local_addr,
		 sizeof(ev.u.ice.local_address));
	str_ncpy(ev.u.ice.remote_address, c->ice_remote_addr,
		 sizeof(ev.u.ice.remote_address));
	bsk_emit(e, &ev);
}


struct make_arg {
	bsk_account_id account;
	const char *destination;
	bool video;
	bsk_call_id id;
};


static int make_op(bsk_engine *e, void *arg)
{
	struct make_arg *ma = arg;
	struct bsk_account_ctx *a;
	struct bsk_call_ctx *c;
	struct call *call = NULL;
	int err;

	a = ma->account == BSK_ID_NONE ? (e->accounts.head ?
					   e->accounts.head->data : NULL)
		: bsk_account_find(e, ma->account);
	if (!a)
		return ENOENT;

	err = ua_connect_dir(a->ua, &call, NULL, ma->destination,
			     ma->video ? VIDMODE_ON : VIDMODE_OFF,
			     SDP_SENDRECV,
			     ma->video ? SDP_SENDRECV : SDP_INACTIVE);
	if (err)
		return err;

	c = bsk_call_find_call(e, call);
	if (!c) {
		c = call_ctx_alloc(e, call, a->id, true);
		if (!c)
			return ENOMEM;
		emit_state(e, c, BSK_CALL_OUTGOING_INIT, NULL);
	}
	c->video = ma->video;
	ma->id = c->id;

	return 0;
}


bsk_status bsk_call_make(bsk_engine *engine, bsk_account_id account,
			 const char *destination, bool video,
			 bsk_call_id *out_id, bsk_error *err)
{
	struct make_arg ma = { account, destination, video, BSK_ID_NONE };
	int ret;

	bsk_error_clear(err);

	if (!engine || !str_isset(destination) || !out_id)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "destination required");

	ret = bsk_run(engine, make_op, &ma);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "call setup failed: %m", ret);

	*out_id = ma.id;
	return BSK_OK;
}


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


static struct ua *call_ua(bsk_engine *e, struct bsk_call_ctx *c)
{
	struct bsk_account_ctx *a = bsk_account_find(e, c->account);
	return a ? a->ua : call_get_ua(c->call);
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
	return ua_answer(call_ua(e, c), c->call,
			 ca->flag ? VIDMODE_ON : VIDMODE_OFF);
}


static int progress_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	err = call_progress_dir(c->call, SDP_SENDRECV,
				ca->flag ? SDP_SENDRECV : SDP_INACTIVE);
	if (!err)
		emit_state(e, c, BSK_CALL_EARLY_MEDIA, NULL);

	return err;
}


static int hangup_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	ua_hangup(call_ua(e, c), c->call, ca->code, ca->str);
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
	emit_state(e, c, ca->flag ? BSK_CALL_PAUSING : BSK_CALL_RESUMING,
		   NULL);

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
				emit_state(e, o, BSK_CALL_PAUSING, NULL);
			}
		}
	}

	if (c->local_hold) {
		err = call_hold(c->call, false);
		if (err)
			return err;
		c->local_hold = false;
		emit_state(e, c, BSK_CALL_RESUMING, NULL);
	}

	call_set_current(ua_calls(call_ua(e, c)), c->call);
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

	call_set_audio_ldir(c->call, unmap_dir(ca->dir));
	err = call_modify(c->call);
	if (!err)
		emit_state(e, c, BSK_CALL_UPDATING, NULL);
	return err;
}


static int video_dir_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	err = call_set_video_dir(c->call, unmap_dir(ca->dir));
	if (!err)
		emit_state(e, c, BSK_CALL_UPDATING, NULL);
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
	emit_media(e, c, BSK_MEDIA_KEYFRAME_REQUESTED, "application");
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

	rate_apply(e, c, true);
	return 0;
}


static int ice_restart_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	int err;
	struct bsk_call_ctx *c = ctx_or_enoent(e, ca->id, &err);

	if (!c)
		return err;

	return restart_ice(c);
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

	fill_info(c, (bsk_call_info *)ca->str);
	return 0;
}


static int stats_op(bsk_engine *e, void *arg)
{
	struct call_arg *ca = arg;
	struct bsk_call_ctx *c = bsk_call_find(e, ca->id);

	if (!c)
		return ENOENT;

	fill_stats(c, (bsk_call_statistics *)ca->str);
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
	struct call_arg ca = { call, false, sip_status ? sip_status : 486,
			       reason ? reason : "Busy Here", 0, 0, 0 };
	return run_call(engine, hangup_op, &ca, err, "reject");
}


bsk_status bsk_call_hangup(bsk_engine *engine, bsk_call_id call,
			   bsk_error *err)
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


bsk_status bsk_call_set_video_max_bitrate(bsk_engine *engine,
					  bsk_call_id call,
					  uint32_t bitrate_bps, bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, bitrate_bps, 0, 0 };
	return run_call(engine, video_bitrate_op, &ca, err,
			"video bitrate");
}


bsk_status bsk_call_restart_ice(bsk_engine *engine, bsk_call_id call,
				bsk_error *err)
{
	struct call_arg ca = { call, false, 0, NULL, 0, 0, 0 };
	return run_call(engine, ice_restart_op, &ca, err, "ICE restart");
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
