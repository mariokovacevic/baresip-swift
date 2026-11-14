#include <string.h>
#include "bsk_internal.h"
#include "bsk_call_internal.h"
#include "bsk_reason.h"


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
	tmr_cancel(&c->tmr_hangup);
	tmr_cancel(&c->tmr_modify);
	if (c->recording)
		(void)bsk_record_stop(&c->recording);
	if (e)
		bsk_video_detach_call(e, c);
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
	struct bsk_account_ctx *a = bsk_account_find(e, account);
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
	if (a && a->rtp_timeout_ms)
		call_enable_rtp_timeout(call, a->rtp_timeout_ms);
	tmr_init(&c->tmr_dtmf);
	tmr_init(&c->tmr_hangup);
	tmr_init(&c->tmr_modify);
	mtx_lock(&e->video_mtx);
	list_append(&e->calls, &c->le, c);
	mtx_unlock(&e->video_mtx);
	bsk_video_bind_call(c);

	return c;
}


static enum sdp_dir negotiated_dir(const struct stream *strm)
{
	struct sdp_media *m = strm ? stream_sdpmedia(strm) : NULL;

	if (!m || sdp_media_disabled(m) || !sdp_media_rformat(m, NULL))
		return SDP_INACTIVE;

	return sdp_media_dir(m);
}


static void get_dirs(struct call *call, enum sdp_dir *adir, enum sdp_dir *vdir)
{
	*adir = negotiated_dir(audio_strm(call_audio(call)));
	*vdir = negotiated_dir(video_strm(call_video(call)));
}


static bsk_media_direction map_dir(enum sdp_dir dir)
{
	switch (dir) {
	case SDP_SENDONLY: return BSK_DIR_SENDONLY;
	case SDP_RECVONLY: return BSK_DIR_RECVONLY;
	case SDP_SENDRECV: return BSK_DIR_SENDRECV;
	default: return BSK_DIR_INACTIVE;
	}
}


enum sdp_dir bsk_call_unmap_dir(bsk_media_direction dir)
{
	switch (dir) {
	case BSK_DIR_SENDONLY: return SDP_SENDONLY;
	case BSK_DIR_RECVONLY: return SDP_RECVONLY;
	case BSK_DIR_SENDRECV: return SDP_SENDRECV;
	default: return SDP_INACTIVE;
	}
}


enum sdp_dir bsk_call_audio_dir(bool audio)
{
	return audio ? SDP_SENDRECV : SDP_INACTIVE;
}


enum sdp_dir bsk_call_video_dir(bool send_camera)
{
	return send_camera ? SDP_SENDRECV : SDP_RECVONLY;
}


void bsk_call_set_lasting_dirs(struct call *call, enum sdp_dir adir,
			       enum sdp_dir vdir)
{
	call_set_mdir(call, adir, vdir);
	call_set_media_estdir(call, adir, vdir);
}


void bsk_call_fill_info(struct bsk_call_ctx *c, bsk_call_info *info)
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
	info->replaces = c->replaces;

	if (!call)
		return;

	info->has_video = call_has_video(call);
	get_dirs(call, &adir, &vdir);
	info->audio_dir = map_dir(adir);
	info->video_dir = map_dir(vdir);
	info->microphone_muted = c->muted;
	str_ncpy(info->sip_call_id, call_id(call) ? call_id(call) : "",
		 sizeof(info->sip_call_id));
	str_ncpy(info->remote_uri, call_peeruri(call) ? call_peeruri(call) : "",
		 sizeof(info->remote_uri));
	str_ncpy(info->remote_display_name,
		 call_peername(call) ? call_peername(call) : "",
		 sizeof(info->remote_display_name));
	ac = audio_codec(call_audio(call), true);
	if (ac)
		str_ncpy(info->audio_codec, ac->name,
			 sizeof(info->audio_codec));
	vc = video_codec(call_video(call), true);
	if (vc)
		str_ncpy(info->video_codec, vc->name,
			 sizeof(info->video_codec));
	info->setup_ms = call_setup_duration(call) * 1000;
	info->duration_s = call_duration(call);
}


void bsk_call_emit_state(bsk_engine *e, struct bsk_call_ctx *c,
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
	if (state == BSK_CALL_ENDED)
		ev.u.call_state.end_reason = c->end_reason;

	bsk_emit(e, &ev);
}


void bsk_call_emit_media(bsk_engine *e, struct bsk_call_ctx *c,
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


void bsk_call_apply_audio_activation(bsk_engine *e, struct bsk_call_ctx *c)
{
	struct audio *au = c->call ? call_audio(c->call) : NULL;

	if (!au)
		return;

	if (!audio_started(au)) {
		if (!audio_codec(au, false))
			return;
		if (e->audio_active)
			(void)audio_set_player(au, e->audio_play_mod,
					       e->audio_play_dev);
		else
			(void)audio_set_player(au, NULL, NULL);
		return;
	}

	if (bsk_call_hold_music(e, c)) {
		/* The music replaces the source first, so the microphone never
		 * sends while the call is on hold. */
		if (!c->hold_music &&
		    0 == audio_set_source(au, BSK_HOLD_MODULE, NULL))
			c->hold_music = true;
		if (c->hold_music) {
			audio_mute(au, false);
			stream_set_hold_send(audio_strm(au), true);
		}
	} else {
		stream_set_hold_send(audio_strm(au), false);
		c->hold_music = false;
		if (e->audio_active)
			(void)audio_set_source(au, e->audio_src_mod,
					       e->audio_src_dev);
		else
			(void)audio_set_source(au, NULL, NULL);
		if (e->audio_active && c->muted)
			audio_mute(au, true);
	}

	if (e->audio_active)
		(void)audio_set_player(au, e->audio_play_mod,
				       e->audio_play_dev);
	else
		(void)audio_set_player(au, NULL, NULL);
}


static bsk_call_end_reason end_reason(uint16_t cause)
{
	switch (cause) {
	case 200: return BSK_END_ANSWERED_ELSEWHERE;
	case 600:
	case 603: return BSK_END_DECLINED_ELSEWHERE;
	default: return BSK_END_NORMAL;
	}
}


static bool ended_elsewhere(const struct bsk_call_ctx *c, const char *text,
			    uint16_t *cause, char *phrase, size_t size)
{
	if (c->outgoing || c->local_hangup)
		return false;

	if (c->state != BSK_CALL_INCOMING && c->state != BSK_CALL_EARLY_MEDIA)
		return false;

	if (!bsk_reason_sip_cause(text, cause, phrase, size))
		return false;

	return end_reason(*cause) != BSK_END_NORMAL;
}


static void finish_call(bsk_engine *e, struct bsk_call_ctx *c,
			struct bevent *event)
{
	const char *text = bevent_get_text(event);
	uint16_t scode = c->call ? call_scode(c->call) : 0;
	bsk_error error;
	char phrase[sizeof(error.sip_reason)];
	uint16_t cause = 0;
	bool failed;

	failed = c->outgoing && !c->local_hangup &&
		 (c->state == BSK_CALL_OUTGOING_INIT ||
		  c->state == BSK_CALL_OUTGOING_RINGING ||
		  c->state == BSK_CALL_EARLY_MEDIA) &&
		 (scode >= 300 || (scode == 0 && str_isset(text)));

	if (failed)
		bsk_error_set(&error,
			      scode >= 300 ? BSK_ERR_SIP : BSK_ERR_NETWORK, 0,
			      scode, NULL, "%s", text ? text : "");
	else if (ended_elsewhere(c, text, &cause, phrase, sizeof(phrase))) {
		c->end_reason = end_reason(cause);
		bsk_error_set(&error, BSK_OK, 0, cause, phrase, "%s", text);
	} else
		bsk_error_set(&error, BSK_OK, 0, c->local_hangup ? 0 : scode,
			      NULL, "%s", text ? text : "");

	if (!failed && !c->local_hangup && c->successor &&
	    bsk_call_find(e, c->successor))
		c->end_reason = BSK_END_REPLACED;

	c->closing = true;
	tmr_cancel(&c->tmr_dtmf);
	tmr_cancel(&c->tmr_hangup);
	tmr_cancel(&c->tmr_modify);
	if (c->recording) {
		(void)bsk_record_stop(&c->recording);
		bsk_call_emit_media(e, c, BSK_MEDIA_RECORDING_STOPPED, NULL);
	}
	bsk_call_emit_state(e, c, failed ? BSK_CALL_FAILED : BSK_CALL_ENDED,
			    &error);
	bsk_video_detach_call(e, c);
	c->call = NULL;
	bsk_call_emit_state(e, c, BSK_CALL_RELEASED, NULL);
	mem_deref(c);
}


bool bsk_call_established(const struct bsk_call_ctx *c)
{
	switch (c->state) {
	case BSK_CALL_CONNECTED:
	case BSK_CALL_STREAMS_RUNNING:
	case BSK_CALL_PAUSING:
	case BSK_CALL_PAUSED:
	case BSK_CALL_RESUMING:
	case BSK_CALL_PAUSED_BY_REMOTE:
	case BSK_CALL_UPDATING: return true;
	default: return false;
	}
}


void bsk_calls_hangup_account(bsk_engine *e, bsk_account_id account)
{
	struct le *le = e->calls.head;

	e->replace_call = NULL;
	e->replace_confirmed = false;
	e->replaced_id = BSK_ID_NONE;

	while (le) {
		struct bsk_call_ctx *c = le->data;

		le = le->next;
		if (!c->call || c->closing)
			continue;
		if (account != BSK_ID_NONE && c->account != account)
			continue;

		c->local_hangup = true;
		ua_hangup(call_get_ua(c->call), c->call, 0, NULL);
	}
}


int bsk_call_start_preview(bsk_engine *e, struct bsk_call_ctx *c, bool audio,
			   bool video);


static void follow_transfer(bsk_engine *e, struct bsk_call_ctx *c,
			    const char *target)
{
	struct bsk_account_ctx *a = bsk_account_find(e, c->account);
	struct bsk_call_ctx *n;
	struct call *call2 = NULL;
	struct pl pl;
	int err;

	if (!a || a->reject_transfers || !bsk_call_established(c)) {
		(void)call_notify_sipfrag(c->call, 603, "Declined");
		return;
	}

	err = ua_call_alloc(&call2, a->ua, VIDMODE_ON, NULL, c->call,
			    call_localuri(c->call), true);
	if (!err) {
		bsk_call_set_lasting_dirs(call2, SDP_SENDRECV,
					  bsk_call_video_dir(c->video));
		n = call_ctx_alloc(e, call2, a->id, true);
		if (!n) {
			err = ENOMEM;
		} else {
			n->video = c->video;
			n->replaces = c->id;
			c->successor = n->id;
			pl_set_str(&pl, target);
			err = call_connect(call2, &pl);
		}
	}

	if (err) {
		(void)call_notify_sipfrag(c->call, 500, "Call Error");
		n = bsk_call_find_call(e, call2);
		if (n)
			finish_call(e, n, NULL);
		mem_deref(call2);
	}
}
static bool other_call_active(const bsk_engine *e,
			      const struct bsk_call_ctx *c);


static bool replaces_text(const char *text)
{
	static const char suffix[] = " replaced";
	size_t len = str_len(text);

	return len > sizeof(suffix) - 1 &&
	       0 == strcmp(text + len - (sizeof(suffix) - 1), suffix);
}


void bsk_call_handle_invite(bsk_engine *e, struct bevent *event)
{
	const struct sip_msg *msg = bevent_get_msg(event);
	const struct sip_hdr *hdr;
	struct ua *ua;

	if (!msg)
		return;

	ua = uag_find_msg(msg);
	if (!ua)
		return;

	hdr = sip_msg_hdr(msg, SIP_HDR_REPLACES);
	e->replace_call = NULL;
	e->replace_confirmed = false;
	e->replaced_id = BSK_ID_NONE;
	e->replace_pending = hdr && pl_isset(&hdr->val);

	(void)ua_accept(ua, msg);

	e->replace_pending = false;
	if (e->replace_confirmed) {
		e->replace_call = ua_find_call_msg(ua, msg);
		if (!e->replace_call) {
			e->replace_confirmed = false;
			e->replaced_id = BSK_ID_NONE;
		}
	}
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
		bool replaces;

		c = call_ctx_alloc(e, call, a ? a->id : BSK_ID_NONE, false);
		if (!c)
			return;
		c->video = call_has_video(call);
		replaces = e->replace_confirmed &&
			   (e->replace_pending || e->replace_call == call);
		if (replaces) {
			c->replaces = e->replaced_id;
			e->replace_confirmed = false;
			e->replace_call = NULL;
			e->replaced_id = BSK_ID_NONE;
		}

		bsk_event_init(&bev, BSK_EVENT_CALL_INCOMING);
		bev.account = c->account;
		bev.call = c->id;
		bsk_call_fill_info(c, &bev.u.call_incoming.info);
		bev.u.call_incoming.early_video =
			call_early_video_available(call);
		bsk_emit(e, &bev);
		if (c->hangup_pending ||
		    call_state(call) != CALL_STATE_INCOMING)
			return;
		if (a && replaces) {
			c->video = e->replace_video && call_has_video(call);
			bsk_call_set_lasting_dirs(call, SDP_SENDRECV,
						  bsk_call_video_dir(c->video));
			(void)ua_answer(a->ua, call, VIDMODE_ON);
			return;
		}
		if (a && a->answer_early_media && !other_call_active(e, c))
			(void)bsk_call_start_preview(e, c, true, true);
		return;
	}

	if (ev == BEVENT_CALL_CLOSED && call && e->replace_call == call) {
		e->replace_call = NULL;
		e->replace_confirmed = false;
		e->replaced_id = BSK_ID_NONE;
	}

	if (!c)
		return;

	switch (ev) {
	case BEVENT_CALL_OUTGOING:
		bsk_call_emit_state(e, c, BSK_CALL_OUTGOING_INIT, NULL);
		break;

	case BEVENT_CALL_RINGING:
		bsk_call_emit_state(e, c, BSK_CALL_OUTGOING_RINGING, NULL);
		break;

	case BEVENT_CALL_PROGRESS:
		bsk_call_emit_state(e, c, BSK_CALL_EARLY_MEDIA, NULL);
		if (call_early_video_available(call))
			bsk_call_emit_media(
				e, c, BSK_MEDIA_EARLY_VIDEO_AVAILABLE, NULL);
		break;

	case BEVENT_CALL_ANSWERED:
	case BEVENT_CALL_ESTABLISHED:
		if (c->state != BSK_CALL_CONNECTED &&
		    c->state != BSK_CALL_STREAMS_RUNNING)
			bsk_call_emit_state(e, c, BSK_CALL_CONNECTED, NULL);
		if (c->rtp_established && c->state == BSK_CALL_CONNECTED)
			bsk_call_emit_state(e, c, BSK_CALL_STREAMS_RUNNING,
					    NULL);
		bsk_call_apply_audio_activation(e, c);
		break;

	case BEVENT_CALL_RTPESTAB:
		c->rtp_established = true;
		if (!e->audio_active)
			bsk_call_apply_audio_activation(e, c);
		bsk_call_emit_media(e, c, BSK_MEDIA_AUDIO_STARTED, text);
		if (c->state == BSK_CALL_CONNECTED)
			bsk_call_emit_state(e, c, BSK_CALL_STREAMS_RUNNING,
					    NULL);
		break;

	case BEVENT_CALL_HOLD:
		c->remote_hold = true;
		bsk_call_emit_media(e, c, BSK_MEDIA_REMOTE_HOLD, NULL);
		if (!c->local_hold)
			bsk_call_emit_state(e, c, BSK_CALL_PAUSED_BY_REMOTE,
					    NULL);
		break;

	case BEVENT_CALL_RESUME:
		c->remote_hold = false;
		bsk_call_emit_media(e, c, BSK_MEDIA_REMOTE_RESUME, NULL);
		if (!c->local_hold) {
			bsk_call_emit_state(e, c, BSK_CALL_STREAMS_RUNNING,
					    NULL);
			if (call_has_video(call)) {
				video_req_keyframe(call_video(call));
				bsk_call_emit_media(
					e, c, BSK_MEDIA_KEYFRAME_REQUESTED,
					"remote resume");
			}
		}
		break;

	case BEVENT_CALL_REMOTE_SDP:
		if (text && 0 == str_casecmp(text, "answer") &&
		    !c->hold_queued) {
			if (c->state == BSK_CALL_PAUSING)
				bsk_call_emit_state(e, c, BSK_CALL_PAUSED,
						    NULL);
			else if (c->state == BSK_CALL_RESUMING) {
				bsk_call_emit_state(
					e, c, BSK_CALL_STREAMS_RUNNING, NULL);
				if (call_has_video(call)) {
					video_req_keyframe(call_video(call));
					bsk_call_emit_media(
						e, c,
						BSK_MEDIA_KEYFRAME_REQUESTED,
						"local resume");
				}
			} else if (c->state == BSK_CALL_UPDATING)
				bsk_call_emit_state(e, c, c->steady_state,
						    NULL);
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
		dev.u.dtmf.via_sip_info = call_dtmf_via_info(call);
		bsk_emit(e, &dev);
		break;
	}

	case BEVENT_CALL_MENC:
		bsk_call_emit_media(e, c, BSK_MEDIA_ENCRYPTION_ESTABLISHED,
				    text);
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
		if (ev == BEVENT_CALL_TRANSFER && !bsk_call_established(c)) {
			(void)call_notify_sipfrag(call, 603, "Declined");
			break;
		}
		bsk_emit(e, &tev);
		if (ev == BEVENT_CALL_TRANSFER && str_isset(text) &&
		    !c->hangup_pending)
			follow_transfer(e, c, text);
		break;
	}

	case BEVENT_CALL_RTCP: {
		bsk_event sev;
		bsk_event_init(&sev, BSK_EVENT_CALL_STATISTICS);
		sev.account = c->account;
		sev.call = c->id;
		bsk_call_fill_stats(c, &sev.u.statistics.stats);
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
		if (e->replace_pending && replaces_text(text) &&
		    bsk_call_established(c)) {
			e->replace_confirmed = true;
			e->replace_video = c->video;
			e->replaced_id = c->id;
			c->local_hangup = true;
			c->end_reason = BSK_END_REPLACED;
		}
		finish_call(e, c, event);
		break;

	default: break;
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


bool bsk_ice_parse_event(const char *text, size_t len, struct bsk_ice_info *out)
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
	} else
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
	bool audio;
	bsk_call_id id;
};


static int make_op(bsk_engine *e, void *arg)
{
	struct make_arg *ma = arg;
	struct bsk_account_ctx *a;
	struct bsk_call_ctx *c;
	struct call *call = NULL;
	int err;

	a = ma->account == BSK_ID_NONE ? bsk_account_default(e)
				       : bsk_account_find(e, ma->account);
	if (!a)
		return ENOENT;
	if (e->stop_requested)
		return EALREADY;

	err = ua_connect_dir(a->ua, &call, NULL, ma->destination, VIDMODE_ON,
			     bsk_call_audio_dir(ma->audio),
			     bsk_call_video_dir(ma->video));
	if (err)
		return err;

	c = bsk_call_find_call(e, call);
	if (!c) {
		c = call_ctx_alloc(e, call, a->id, true);
		if (!c)
			return ENOMEM;
		bsk_call_emit_state(e, c, BSK_CALL_OUTGOING_INIT, NULL);
	}
	c->video = ma->video;
	ma->id = c->id;

	return 0;
}


bsk_status bsk_call_make(bsk_engine *engine, bsk_account_id account,
			 const char *destination, bool video,
			 bsk_call_id *out_id, bsk_error *err)
{
	return bsk_call_make_media(engine, account, destination, true, video,
				   out_id, err);
}


bsk_status bsk_call_make_media(bsk_engine *engine, bsk_account_id account,
			       const char *destination, bool audio, bool video,
			       bsk_call_id *out_id, bsk_error *err)
{
	struct make_arg ma = { account, destination, video, audio,
			       BSK_ID_NONE };
	int ret;

	bsk_error_clear(err);

	if (!engine || !str_isset(destination) || !out_id)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "destination required");

	if (!bsk_text_safe(destination))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL,
				     "destination must not contain "
				     "control characters");

	ret = bsk_run(engine, make_op, &ma);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "call setup failed: %m", ret);

	*out_id = ma.id;
	return BSK_OK;
}


struct ua *bsk_call_owning_ua(bsk_engine *e, struct bsk_call_ctx *c)
{
	struct bsk_account_ctx *a = bsk_account_find(e, c->account);
	return a ? a->ua : call_get_ua(c->call);
}


enum sdp_dir bsk_call_preview_adir(const struct bsk_call_ctx *c)
{
	return c->preview_audio ? SDP_RECVONLY : SDP_INACTIVE;
}


enum sdp_dir bsk_call_preview_vdir(const struct bsk_call_ctx *c)
{
	return c->preview_video && call_has_video(c->call) ? SDP_RECVONLY
							   : SDP_INACTIVE;
}


int bsk_call_start_preview(bsk_engine *e, struct bsk_call_ctx *c, bool audio,
			   bool video)
{
	int err;

	c->preview_audio = audio;
	c->preview_video = video;
	err = call_progress_dir(c->call, bsk_call_preview_adir(c),
				bsk_call_preview_vdir(c));
	if (err && err != EAGAIN)
		return err;

	c->early_preview = true;
	bsk_call_emit_state(e, c, BSK_CALL_EARLY_MEDIA, NULL);
	return 0;
}


static bool other_call_active(const bsk_engine *e, const struct bsk_call_ctx *c)
{
	struct le *le;

	for (le = e->calls.head; le; le = le->next) {
		const struct bsk_call_ctx *o = le->data;

		if (o == c || !o->call)
			continue;
		if (o->state == BSK_CALL_ENDED || o->state == BSK_CALL_FAILED ||
		    o->state == BSK_CALL_RELEASED)
			continue;
		return true;
	}

	return false;
}
