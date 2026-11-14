#include <string.h>
#include "bsk_internal.h"
#include "bsk_call_internal.h"


static bool call_uses_ice(const struct bsk_call_ctx *c)
{
	const char *mnat;

	if (!c->call)
		return false;

	mnat = account_medianat(call_account(c->call));

	return mnat && 0 == str_casecmp(mnat, "ice");
}


int bsk_call_ice_restart(struct bsk_call_ctx *c)
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


void bsk_call_rate_apply(bsk_engine *e, struct bsk_call_ctx *c, bool force)
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
	} else if (!force) {
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

		bsk_call_rate_apply(engine, c, false);
	}
}


void bsk_calls_recording_failed(bsk_engine *engine, const void *handle)
{
	struct le *le;

	if (!engine)
		return;

	for (le = engine->calls.head; le; le = le->next) {
		struct bsk_call_ctx *c = le->data;
		bsk_event ev;

		if (c->recording != handle)
			continue;

		(void)bsk_record_stop(&c->recording);
		bsk_event_init(&ev, BSK_EVENT_AUDIO);
		ev.account = c->account;
		ev.call = c->id;
		bsk_error_set(&ev.u.audio.error, BSK_ERR_MEDIA, EIO, 0, NULL,
			      "the recording could not be written");
		ev.u.audio.input_running = engine->audio_active;
		ev.u.audio.output_running = engine->audio_active;
		bsk_emit(engine, &ev);
		bsk_call_emit_media(engine, c, BSK_MEDIA_RECORDING_STOPPED,
				    "write error");
		return;
	}
}


void bsk_calls_audio_changed(bsk_engine *engine)
{
	struct le *le;

	for (le = engine->calls.head; le; le = le->next)
		bsk_call_apply_audio_activation(engine, le->data);
}


void bsk_call_fill_stats(struct bsk_call_ctx *c, bsk_call_statistics *st)
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
			st->audio.rx_lost = rs->rx.lost > 0 ? rs->rx.lost : 0;
			st->audio.rx_jitter_ms = rs->rx.jit / 1000;
			st->audio.rtt_ms = rs->rtt / 1000;
			st->audio.rx_fraction_lost_permille =
				bsk_loss_permille(rs->rx.sent, rs->rx.lost);
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
			st->video.rx_lost = rs->rx.lost > 0 ? rs->rx.lost : 0;
			st->video.rx_jitter_ms = rs->rx.jit / 1000;
			st->video.rtt_ms = rs->rtt / 1000;
		}
	}

	st->ice_state = c->ice_state;
	st->local_candidate = c->ice_local_type;
	st->remote_candidate = c->ice_remote_type;
	str_ncpy(st->local_address, c->ice_local_addr,
		 sizeof(st->local_address));
	str_ncpy(st->remote_address, c->ice_remote_addr,
		 sizeof(st->remote_address));

	st->mos_estimate = bsk_mos_estimate(st->audio.rx_fraction_lost_permille,
					    st->audio.rtt_ms,
					    st->audio.jitter_buffer_delay_ms);
}
