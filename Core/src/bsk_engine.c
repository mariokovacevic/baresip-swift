#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include "bsk_internal.h"

#define BSK_VERSION_STRING "0.1.0"

static bsk_engine *g_engine;

static const char *default_modules[] = {
	"g711", "opus", "l16", "auconv", "auresamp",
	"ice", "turn", "stun", "srtp", "dtls_srtp", "rtcpsummary",
#if defined(__APPLE__)
	"audiounit", "fakevideo",
#endif
};


bsk_engine *bsk_global_engine(void)
{
	return g_engine;
}


uint32_t bsk_abi_version(void)
{
	return ((uint32_t)BSK_ABI_VERSION_MAJOR << 16) | BSK_ABI_VERSION_MINOR;
}


const char *bsk_version_string(void)
{
	return BSK_VERSION_STRING;
}


const char *bsk_status_string(bsk_status status)
{
	switch (status) {
	case BSK_OK:                   return "ok";
	case BSK_ERR_INVALID_ARGUMENT: return "invalid argument";
	case BSK_ERR_INVALID_STATE:    return "invalid state";
	case BSK_ERR_NOT_FOUND:        return "not found";
	case BSK_ERR_NO_MEMORY:        return "out of memory";
	case BSK_ERR_UNSUPPORTED:      return "unsupported";
	case BSK_ERR_BUSY:             return "busy";
	case BSK_ERR_TIMEOUT:          return "timeout";
	case BSK_ERR_NETWORK:          return "network error";
	case BSK_ERR_TLS:              return "tls error";
	case BSK_ERR_AUTH:             return "authentication failed";
	case BSK_ERR_SIP:              return "sip error";
	case BSK_ERR_MEDIA:            return "media error";
	case BSK_ERR_BUFFER_TOO_SMALL: return "buffer too small";
	default:                       return "internal error";
	}
}


uint64_t bsk_now_ms(void)
{
	return tmr_jiffies();
}


void bsk_error_clear(bsk_error *err)
{
	if (err)
		memset(err, 0, sizeof(*err));
}


bsk_status bsk_error_set(bsk_error *err, bsk_status status, int sys_errno,
			 uint16_t sip_status, const char *sip_reason,
			 const char *fmt, ...)
{
	if (!err)
		return status;

	memset(err, 0, sizeof(*err));
	err->status = status;
	err->sys_errno = sys_errno;
	err->sip_status = sip_status;
	if (sip_reason)
		str_ncpy(err->sip_reason, sip_reason, sizeof(err->sip_reason));
	if (fmt) {
		va_list ap;
		va_start(ap, fmt);
		(void)re_vsnprintf(err->message, sizeof(err->message), fmt, ap);
		va_end(ap);
	}

	return status;
}


bsk_status bsk_status_from_errno(int err)
{
	switch (err) {
	case 0:            return BSK_OK;
	case EINVAL:       return BSK_ERR_INVALID_ARGUMENT;
	case ENOMEM:       return BSK_ERR_NO_MEMORY;
	case ENOENT:       return BSK_ERR_NOT_FOUND;
	case ENODEV:       return BSK_ERR_NOT_FOUND;
	case ENOSYS:       return BSK_ERR_UNSUPPORTED;
	case EPROTONOSUPPORT: return BSK_ERR_UNSUPPORTED;
	case EBUSY:        return BSK_ERR_BUSY;
	case EALREADY:     return BSK_ERR_INVALID_STATE;
	case ETIMEDOUT:    return BSK_ERR_TIMEOUT;
	case EAUTH:        return BSK_ERR_AUTH;
	case ECONNREFUSED:
	case ECONNRESET:
	case EHOSTUNREACH:
	case ENETUNREACH:
	case EADDRNOTAVAIL: return BSK_ERR_NETWORK;
	default:           return BSK_ERR_INTERNAL;
	}
}


bool bsk_on_engine_thread(const bsk_engine *engine)
{
	if (!engine || !engine->thread_valid)
		return false;

	return thrd_equal(thrd_current(), engine->thread);
}


bool bsk_engine_is_engine_thread(const bsk_engine *engine)
{
	return bsk_on_engine_thread(engine);
}


void bsk_event_init(bsk_event *ev, bsk_event_type type)
{
	memset(ev, 0, sizeof(*ev));
	ev->type = type;
	ev->timestamp_ms = bsk_now_ms();
}


void bsk_emit(bsk_engine *engine, bsk_event *ev)
{
	if (!engine || !ev)
		return;

	mtx_lock(&engine->cb_mtx);
	if (engine->handler)
		engine->handler(engine, ev, engine->user);
	mtx_unlock(&engine->cb_mtx);
}


static void set_state(bsk_engine *engine, bsk_engine_state state,
		      const bsk_error *error)
{
	bsk_event ev;

	engine->state = state;

	bsk_event_init(&ev, BSK_EVENT_ENGINE_STATE);
	ev.u.engine.state = state;
	if (error)
		ev.u.engine.error = *error;

	bsk_emit(engine, &ev);
}


static void mq_handler(int id, void *data, void *arg)
{
	bsk_engine *engine = arg;
	struct bsk_op *op = data;
	(void)id;

	mtx_lock(&engine->mtx);
	list_unlink(&op->le);
	mtx_unlock(&engine->mtx);

	op->ret = op->fn(engine, op->arg);

	mtx_lock(&op->mtx);
	op->done = true;
	cnd_signal(&op->cnd);
	mtx_unlock(&op->mtx);
}


static void close_ops(bsk_engine *e)
{
	struct le *le;

	mtx_lock(&e->mtx);
	e->mq_open = false;
	while ((le = list_head(&e->pending_ops))) {
		struct bsk_op *op = le->data;

		list_unlink(&op->le);
		mtx_lock(&op->mtx);
		op->ret = ECANCELED;
		op->done = true;
		cnd_signal(&op->cnd);
		mtx_unlock(&op->mtx);
	}
	mtx_unlock(&e->mtx);
}


int bsk_run(bsk_engine *engine, bsk_op_fn *fn, void *arg)
{
	struct bsk_op op;
	int err;

	if (!engine || !fn)
		return EINVAL;

	if (bsk_on_engine_thread(engine))
		return fn(engine, arg);

	memset(&op, 0, sizeof(op));
	op.fn = fn;
	op.arg = arg;
	mtx_init(&op.mtx, mtx_plain);
	cnd_init(&op.cnd);

	mtx_lock(&engine->mtx);
	if (!engine->mq_open || !engine->mq) {
		mtx_unlock(&engine->mtx);
		err = EALREADY;
		goto out;
	}
	list_append(&engine->pending_ops, &op.le, &op);
	err = mqueue_push(engine->mq, 0, &op);
	if (err)
		list_unlink(&op.le);
	mtx_unlock(&engine->mtx);
	if (err)
		goto out;

	mtx_lock(&op.mtx);
	while (!op.done)
		cnd_wait(&op.cnd, &op.mtx);
	mtx_unlock(&op.mtx);

	err = op.ret;

 out:
	cnd_destroy(&op.cnd);
	mtx_destroy(&op.mtx);

	return err;
}


static int dup_str(char **dst, const char *src)
{
	*dst = NULL;
	if (!str_isset(src))
		return 0;
	return str_dup(dst, src);
}


static int copy_config(bsk_engine *e, const bsk_engine_config *c)
{
	int err = 0;
	size_t i;

	err |= dup_str(&e->user_agent, c->user_agent);
	err |= dup_str(&e->instance_uuid, c->instance_uuid);
	err |= dup_str(&e->network_interface, c->network_interface);
	err |= dup_str(&e->extra_config, c->extra_config);
	err |= dup_str(&e->cipher_list, c->tls.cipher_list);

	if (c->tls.ca_pem && c->tls.ca_pem_len) {
		e->ca_pem = mem_zalloc(c->tls.ca_pem_len + 1, NULL);
		if (!e->ca_pem)
			return ENOMEM;
		memcpy(e->ca_pem, c->tls.ca_pem, c->tls.ca_pem_len);
		e->ca_pem_len = c->tls.ca_pem_len;
	}
	if (c->tls.client_cert_pem && c->tls.client_cert_pem_len) {
		e->client_cert_pem = mem_zalloc(c->tls.client_cert_pem_len + 1,
						NULL);
		if (!e->client_cert_pem)
			return ENOMEM;
		memcpy(e->client_cert_pem, c->tls.client_cert_pem,
		       c->tls.client_cert_pem_len);
		e->client_cert_pem_len = c->tls.client_cert_pem_len;
	}

	if (c->tls.pinned_count && c->tls.pinned_spki_sha256_base64) {
		if (c->tls.pinned_count > RE_ARRAY_SIZE(e->pins))
			return EINVAL;
		for (i = 0; i < c->tls.pinned_count; i++)
			err |= dup_str(&e->pins[i],
				       c->tls.pinned_spki_sha256_base64[i]);
		e->pin_count = c->tls.pinned_count;
	}

	e->tls_min_version = c->tls.min_version;
	e->verify_server = c->tls.verify_server;
	e->ipv6 = c->ipv6;
	e->rtp_port_min = c->rtp_port_min ? c->rtp_port_min : 10000;
	e->rtp_port_max = c->rtp_port_max ? c->rtp_port_max : 20000;
	e->max_calls = c->max_calls ? c->max_calls : 4;
	e->log_level = c->log_level;
	e->log_sip_trace = c->log_sip_trace;
	e->ice_relay_only = c->ice_relay_only;
	e->video_adaptive = c->video_adaptive_bitrate;

	if (c->modules && c->module_count) {
		if (c->module_count > BSK_MAX_MODULES)
			return EINVAL;
		for (i = 0; i < c->module_count; i++)
			err |= dup_str(&e->modules[i], c->modules[i]);
		e->module_count = c->module_count;
	}
	else {
		for (i = 0; i < RE_ARRAY_SIZE(default_modules); i++)
			err |= dup_str(&e->modules[i], default_modules[i]);
		e->module_count = RE_ARRAY_SIZE(default_modules);
	}

	str_ncpy(e->audio_src_mod, str_isset(c->audio.source_module) ?
		 c->audio.source_module : "audiounit",
		 sizeof(e->audio_src_mod));
	str_ncpy(e->audio_src_dev, c->audio.source_device ?
		 c->audio.source_device : "", sizeof(e->audio_src_dev));
	str_ncpy(e->audio_play_mod, str_isset(c->audio.player_module) ?
		 c->audio.player_module : "audiounit",
		 sizeof(e->audio_play_mod));
	str_ncpy(e->audio_play_dev, c->audio.player_device ?
		 c->audio.player_device : "", sizeof(e->audio_play_dev));
	e->audio_srate = c->audio.sample_rate;
	e->audio_channels = c->audio.channels;
	e->audio_ptime = c->audio.ptime_ms ? c->audio.ptime_ms : 20;
	e->jb_min_ms = c->audio.jitter_buffer_min_ms ?
		c->audio.jitter_buffer_min_ms : 40;
	e->jb_max_ms = c->audio.jitter_buffer_max_ms ?
		c->audio.jitter_buffer_max_ms : 200;
	e->jb_adaptive = c->audio.jitter_buffer_adaptive;
	e->voice_processing = c->audio.voice_processing;

	str_ncpy(e->video_src_mod, str_isset(c->video.source_module) ?
		 c->video.source_module : "bskcapture", sizeof(e->video_src_mod));
	str_ncpy(e->video_src_dev, c->video.source_device ?
		 c->video.source_device : "", sizeof(e->video_src_dev));
	e->video_width = c->video.width ? c->video.width : 640;
	e->video_height = c->video.height ? c->video.height : 480;
	e->video_fps = c->video.fps ? c->video.fps : 30;
	e->video_bitrate = c->video.bitrate_bps ? c->video.bitrate_bps : 800000;
	e->video_min_bitrate = c->video_min_bitrate_bps ?
		c->video_min_bitrate_bps : 150000;
	if (e->video_min_bitrate > e->video_bitrate)
		e->video_min_bitrate = e->video_bitrate;

	return err;
}


static int build_config(bsk_engine *e, struct mbuf *mb)
{
	int err;

	err = mbuf_printf(mb,
		"sip_transports\t\tudp,tcp,tls,wss\n"
		"sip_verify_server\t%s\n"
		"sip_trans_def\t\tudp\n"
		"call_accept\t\tyes\n"
		"call_max_calls\t\t%u\n"
		"call_local_timeout\t120\n"
		"audio_source\t\t%s,%s\n"
		"audio_player\t\t%s,%s\n"
		"audio_jitter_buffer_type\t%s\n"
		"audio_jitter_buffer_ms\t%u-%u\n"
		"rtp_ports\t\t%u-%u\n"
		"rtp_stats\t\tyes\n"
		"rtp_timeout\t\t30\n"
		"net_af\t\t\t%s\n"
		"dns_getaddrinfo\t\tyes\n"
		"video_source\t\t%s,%s\n"
		"video_display\t\tbsk,\n"
		"video_size\t\t%ux%u\n"
		"video_fps\t\t%u\n"
		"video_bitrate\t\t%u\n",
		e->verify_server ? "yes" : "no",
		e->max_calls,
		e->audio_src_mod, e->audio_src_dev,
		e->audio_play_mod, e->audio_play_dev,
		e->jb_adaptive ? "adaptive" : "fixed",
		e->jb_min_ms, e->jb_max_ms,
		(unsigned)e->rtp_port_min, (unsigned)e->rtp_port_max,
		e->ipv6 ? "unspecified" : "ipv4",
		e->video_src_mod, e->video_src_dev,
		e->video_width, e->video_height, e->video_fps,
		e->video_bitrate);

	if (e->audio_srate)
		err |= mbuf_printf(mb, "ausrc_srate\t\t%u\nauplay_srate\t\t%u\n",
				   e->audio_srate, e->audio_srate);
	if (e->audio_channels)
		err |= mbuf_printf(mb,
				   "ausrc_channels\t\t%u\nauplay_channels\t\t%u\n",
				   e->audio_channels, e->audio_channels);
	err |= mbuf_printf(mb, "ice_policy\t\t%s\n",
			   e->ice_relay_only ? "relay" : "all");
	if (str_isset(e->network_interface))
		err |= mbuf_printf(mb, "net_interface\t\t%s\n",
				   e->network_interface);
	if (str_isset(e->extra_config))
		err |= mbuf_printf(mb, "%s\n", e->extra_config);

	return err;
}


static int apply_tls(bsk_engine *e)
{
	struct tls *tls = uag_tls();
	int err = 0;

	if (!tls)
		return 0;

	if (e->ca_pem)
		err = tls_add_capem(tls, e->ca_pem);
	if (err)
		return err;

	if (e->client_cert_pem) {
		err = tls_set_certificate_pem(tls, e->client_cert_pem,
					      e->client_cert_pem_len,
					      NULL, 0);
		if (err)
			return err;
	}

	if (e->tls_min_version)
		err = tls_set_min_proto_version(tls, e->tls_min_version);
	if (err)
		return err;

	if (e->cipher_list) {
		const char *cipherv[1] = { e->cipher_list };
		err = tls_set_ciphers(tls, cipherv, 1);
	}
	if (err)
		return err;

	return bsk_tls_install_pins(e);
}


static void exit_handler(void *arg)
{
	bsk_engine *e = arg;
	(void)e;

	re_cancel();
}


static void running_handler(void *arg)
{
	bsk_engine *e = arg;

	set_state(e, BSK_ENGINE_RUNNING, NULL);
}


static void rate_handler(void *arg)
{
	bsk_engine *e = arg;

	bsk_calls_rate_tick(e);
	tmr_start(&e->tmr_rate, 1000, rate_handler, e);
}


static void bevent_handler(enum bevent_ev ev, struct bevent *event, void *arg)
{
	bsk_engine *e = arg;

	switch (ev) {

	case BEVENT_REGISTERING:
	case BEVENT_REGISTER_OK:
	case BEVENT_REGISTER_FAIL:
	case BEVENT_UNREGISTERING:
	case BEVENT_FALLBACK_OK:
	case BEVENT_FALLBACK_FAIL:
		bsk_account_handle_event(e, ev, event);
		break;

	case BEVENT_CALL_INCOMING:
	case BEVENT_CALL_OUTGOING:
	case BEVENT_CALL_RINGING:
	case BEVENT_CALL_PROGRESS:
	case BEVENT_CALL_ANSWERED:
	case BEVENT_CALL_ESTABLISHED:
	case BEVENT_CALL_CLOSED:
	case BEVENT_CALL_TRANSFER:
	case BEVENT_CALL_TRANSFER_FAILED:
	case BEVENT_CALL_REDIRECT:
	case BEVENT_CALL_DTMF_START:
	case BEVENT_CALL_DTMF_END:
	case BEVENT_CALL_RTPESTAB:
	case BEVENT_CALL_RTCP:
	case BEVENT_CALL_MENC:
	case BEVENT_CALL_LOCAL_SDP:
	case BEVENT_CALL_REMOTE_SDP:
	case BEVENT_CALL_HOLD:
	case BEVENT_CALL_RESUME:
	case BEVENT_AUDIO_ERROR:
		bsk_call_handle_event(e, ev, event);
		break;

	case BEVENT_MODULE:
		bsk_call_handle_module_event(e, bevent_get_text(event));
		break;

	default:
		break;
	}
}


static void signal_start(bsk_engine *e, int err)
{
	mtx_lock(&e->mtx);
	e->start_err = err;
	e->start_done = true;
	cnd_broadcast(&e->cnd);
	mtx_unlock(&e->mtx);
}


static int engine_thread(void *arg)
{
	bsk_engine *e = arg;
	struct mbuf *mb = NULL;
	struct config *cfg;
	size_t i;
	int err;

	err = libre_init();
	if (err)
		goto fail;

	g_engine = e;
	bsk_log_init(e);

	mb = mbuf_alloc(2048);
	if (!mb) {
		err = ENOMEM;
		goto fail;
	}

	err = build_config(e, mb);
	if (err)
		goto fail;

	err = conf_configure_buf(mb->buf, mb->end);
	if (err)
		goto fail;

	cfg = conf_config();
	if (str_isset(e->instance_uuid))
		str_ncpy(cfg->sip.uuid, e->instance_uuid, sizeof(cfg->sip.uuid));

	err = baresip_init(cfg);
	if (err)
		goto fail;

	err = ua_init(str_isset(e->user_agent) ? e->user_agent :
		      "BaresipKit/" BSK_VERSION_STRING, true, true, true);
	if (err)
		goto fail;

	err = apply_tls(e);
	if (err)
		goto fail;

	for (i = 0; i < e->module_count; i++) {
		int merr = module_load("", e->modules[i]);
		if (merr) {
			char msg[128];
			int n = re_snprintf(msg, sizeof(msg),
					    "bsk: module %s failed: %m",
					    e->modules[i], merr);
			if (n > 0)
				bsk_log_emit(e, BSK_LOG_WARNING,
					     BSK_LOG_DOMAIN_CORE, msg,
					     (size_t)n);
		}
	}

	err = mqueue_alloc(&e->mq, mq_handler, e);
	if (err)
		goto fail;

	mtx_lock(&e->mtx);
	e->mq_open = true;
	mtx_unlock(&e->mtx);

	err = bevent_register(bevent_handler, e);
	if (err)
		goto fail;

	err = bsk_video_init(e);
	if (err)
		goto fail;

	uag_set_exit_handler(exit_handler, e);
	if (e->log_sip_trace)
		sip_set_trace_handler(uag_sip(), bsk_sip_trace_handler);

	e->state = BSK_ENGINE_READY;
	e->t0_ms = bsk_now_ms();
	tmr_start(&e->tmr_running, 0, running_handler, e);
	tmr_start(&e->tmr_rate, 1000, rate_handler, e);
	signal_start(e, 0);

	(void)re_main(NULL);

	tmr_cancel(&e->tmr_stop);
	tmr_cancel(&e->tmr_running);
	tmr_cancel(&e->tmr_rate);
	bevent_unregister(bevent_handler);
	bsk_video_close(e);
	bsk_calls_flush(e);
	bsk_accounts_flush(e);
	close_ops(e);
	e->mq = mem_deref(e->mq);
	ua_close();
	baresip_close();
	mod_close();
	bsk_log_close(e);
	mem_deref(mb);
	g_engine = NULL;
	libre_close();

	mtx_lock(&e->mtx);
	e->stop_done = true;
	cnd_broadcast(&e->cnd);
	mtx_unlock(&e->mtx);

	return 0;

 fail:
	bevent_unregister(bevent_handler);
	bsk_video_close(e);
	close_ops(e);
	e->mq = mem_deref(e->mq);
	ua_close();
	baresip_close();
	mod_close();
	bsk_log_close(e);
	mem_deref(mb);
	g_engine = NULL;
	libre_close();
	e->state = BSK_ENGINE_FAILED;
	signal_start(e, err);
	return err;
}


bsk_status bsk_engine_create(const bsk_engine_config *config,
			     bsk_event_handler handler, void *user,
			     bsk_engine **out_engine, bsk_error *err)
{
	bsk_engine *e;
	int ret;

	bsk_error_clear(err);

	if (!config || !out_engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "config and out_engine required");

	if (g_engine)
		return bsk_error_set(err, BSK_ERR_BUSY, EBUSY, 0, NULL,
				     "only one engine may exist per process");

	e = calloc(1, sizeof(*e));
	if (!e)
		return bsk_error_set(err, BSK_ERR_NO_MEMORY, ENOMEM, 0, NULL,
				     NULL);

	e->handler = handler;
	e->user = user;
	e->state = BSK_ENGINE_IDLE;
	e->next_account_id = 1;
	e->next_call_id = 1;
	list_init(&e->accounts);
	list_init(&e->calls);
	mtx_init(&e->mtx, mtx_plain);
	mtx_init(&e->cb_mtx, mtx_recursive);
	mtx_init(&e->video_mtx, mtx_plain);
	cnd_init(&e->cnd);

	{
		bsk_engine_config local;
		size_t n = config->size ? config->size : sizeof(local);

		if (n > sizeof(local))
			n = sizeof(local);
		memset(&local, 0, sizeof(local));
		memcpy(&local, config, n);
		local.size = (uint32_t)sizeof(local);
		ret = copy_config(e, &local);
	}
	if (ret) {
		bsk_engine_destroy(e);
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "invalid engine configuration");
	}

	*out_engine = e;
	return BSK_OK;
}


void bsk_engine_set_log_handler(bsk_engine *engine, bsk_log_handler handler,
				void *user)
{
	if (!engine)
		return;

	mtx_lock(&engine->cb_mtx);
	engine->logh = handler;
	engine->log_user = user;
	mtx_unlock(&engine->cb_mtx);
}


void bsk_engine_set_event_handler(bsk_engine *engine,
				  bsk_event_handler handler, void *user)
{
	if (!engine)
		return;

	mtx_lock(&engine->cb_mtx);
	engine->handler = handler;
	engine->user = user;
	mtx_unlock(&engine->cb_mtx);
}


bsk_status bsk_engine_start(bsk_engine *engine, bsk_error *err)
{
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	if (engine->state != BSK_ENGINE_IDLE &&
	    engine->state != BSK_ENGINE_STOPPED &&
	    engine->state != BSK_ENGINE_FAILED)
		return bsk_error_set(err, BSK_ERR_INVALID_STATE, EALREADY, 0,
				     NULL, "engine already started");

	if (engine->thread_valid) {
		thrd_join(engine->thread, NULL);
		engine->thread_valid = false;
	}

	engine->start_done = false;
	engine->stop_done = false;
	engine->stop_requested = false;
	engine->state = BSK_ENGINE_STARTING;

	if (thrd_create(&engine->thread, engine_thread, engine) !=
	    thrd_success) {
		engine->state = BSK_ENGINE_FAILED;
		return bsk_error_set(err, BSK_ERR_INTERNAL, EAGAIN, 0, NULL,
				     "could not create engine thread");
	}
	engine->thread_valid = true;

	mtx_lock(&engine->mtx);
	while (!engine->start_done)
		cnd_wait(&engine->cnd, &engine->mtx);
	ret = engine->start_err;
	mtx_unlock(&engine->mtx);

	if (ret) {
		thrd_join(engine->thread, NULL);
		engine->thread_valid = false;
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "engine start failed: %m", ret);
	}

	return BSK_OK;
}


static void force_stop_handler(void *arg)
{
	bsk_engine *e = arg;
	(void)e;

	ua_stop_all(true);
	re_cancel();
}


struct stop_arg {
	uint32_t timeout_ms;
};


static int stop_op(bsk_engine *e, void *arg)
{
	struct stop_arg *sa = arg;

	if (e->stop_requested)
		return 0;

	e->stop_requested = true;
	set_state(e, BSK_ENGINE_STOPPING, NULL);
	ua_stop_all(false);
	tmr_start(&e->tmr_stop, sa->timeout_ms ? sa->timeout_ms : 3000,
		  force_stop_handler, e);

	return 0;
}


bsk_status bsk_engine_stop(bsk_engine *engine, uint32_t timeout_ms,
			   bsk_error *err)
{
	struct stop_arg sa = { timeout_ms };

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	if (bsk_on_engine_thread(engine))
		return bsk_error_set(err, BSK_ERR_INVALID_STATE, EINVAL, 0,
				     NULL, "stop must not be called from the "
				     "engine thread");

	if (!engine->thread_valid)
		return BSK_OK;

	if (engine->state == BSK_ENGINE_READY ||
	    engine->state == BSK_ENGINE_RUNNING)
		(void)bsk_run(engine, stop_op, &sa);

	thrd_join(engine->thread, NULL);
	engine->thread_valid = false;
	engine->state = BSK_ENGINE_STOPPED;

	{
		bsk_event ev;
		bsk_event_init(&ev, BSK_EVENT_ENGINE_STATE);
		ev.u.engine.state = BSK_ENGINE_STOPPED;
		bsk_emit(engine, &ev);
	}

	return BSK_OK;
}


void bsk_engine_destroy(bsk_engine *engine)
{
	size_t i;

	if (!engine)
		return;

	if (engine->thread_valid)
		(void)bsk_engine_stop(engine, 3000, NULL);

	for (i = 0; i < engine->module_count; i++)
		mem_deref(engine->modules[i]);
	for (i = 0; i < engine->pin_count; i++)
		mem_deref(engine->pins[i]);
	mem_deref(engine->user_agent);
	mem_deref(engine->instance_uuid);
	mem_deref(engine->network_interface);
	mem_deref(engine->extra_config);
	mem_deref(engine->cipher_list);
	if (engine->ca_pem)
		mem_deref(engine->ca_pem);
	if (engine->client_cert_pem) {
		memset(engine->client_cert_pem, 0, engine->client_cert_pem_len);
		mem_deref(engine->client_cert_pem);
	}
	cnd_destroy(&engine->cnd);
	mtx_destroy(&engine->video_mtx);
	mtx_destroy(&engine->cb_mtx);
	mtx_destroy(&engine->mtx);
	free(engine);
}


bsk_engine_state bsk_engine_get_state(const bsk_engine *engine)
{
	return engine ? (bsk_engine_state)engine->state : BSK_ENGINE_IDLE;
}


static int reregister_all_op(bsk_engine *e, void *arg)
{
	struct le *le;
	int err = 0;
	(void)arg;

	for (le = e->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;
		if (account_regint(ua_account(a->ua)))
			err |= ua_register(a->ua);
	}

	return err;
}


bsk_status bsk_engine_prepare_for_push_wakeup(bsk_engine *engine,
					      bsk_error *err)
{
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	if (engine->state == BSK_ENGINE_IDLE ||
	    engine->state == BSK_ENGINE_STOPPED ||
	    engine->state == BSK_ENGINE_FAILED)
		return bsk_engine_start(engine, err);

	engine->suspended = false;
	ret = bsk_run(engine, reregister_all_op, NULL);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "re-registration failed: %m", ret);

	return BSK_OK;
}


bsk_status bsk_engine_suspend(bsk_engine *engine, bsk_error *err)
{
	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	engine->suspended = true;
	return BSK_OK;
}


struct net_arg {
	bool reregister;
	bool update_calls;
};


static int network_op(bsk_engine *e, void *arg)
{
	struct net_arg *na = arg;
	bsk_event ev;
	int err;

	err = uag_reset_transp(na->reregister, na->update_calls);

	bsk_event_init(&ev, BSK_EVENT_NETWORK);
	ev.u.network.transports_reset = (err == 0);
	{
		const struct sa *laddr = net_laddr_af(baresip_network(), AF_INET);
		if (!laddr || !sa_isset(laddr, SA_ADDR))
			laddr = net_laddr_af(baresip_network(), AF_INET6);
		if (laddr && sa_isset(laddr, SA_ADDR))
			(void)re_snprintf(ev.u.network.local_address,
					  sizeof(ev.u.network.local_address),
					  "%j", laddr);
	}
	bsk_emit(e, &ev);

	return err;
}


bsk_status bsk_engine_resume(bsk_engine *engine, bsk_error *err)
{
	struct net_arg na = { true, true };
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	engine->suspended = false;
	ret = bsk_run(engine, network_op, &na);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "resume failed: %m", ret);

	return BSK_OK;
}


bsk_status bsk_engine_network_changed(bsk_engine *engine, bool reregister,
				      bool update_calls, bsk_error *err)
{
	struct net_arg na = { reregister, update_calls };
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, network_op, &na);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "transport reset failed: %m", ret);

	return BSK_OK;
}


struct audio_arg {
	bool active;
	bool route_change;
	bool interruption_began;
};


static int audio_op(bsk_engine *e, void *arg)
{
	struct audio_arg *aa = arg;
	bsk_event ev;

	e->audio_active = aa->active;
	bsk_calls_audio_changed(e);

	bsk_event_init(&ev, BSK_EVENT_AUDIO);
	ev.u.audio.input_running = e->audio_active;
	ev.u.audio.output_running = e->audio_active;
	bsk_emit(e, &ev);

	return 0;
}


static bsk_status run_audio(bsk_engine *engine, struct audio_arg *aa,
			    bsk_error *err)
{
	int ret;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, audio_op, aa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "audio change failed: %m", ret);

	return BSK_OK;
}


bsk_status bsk_engine_audio_session_activated(bsk_engine *engine,
					      bsk_error *err)
{
	struct audio_arg aa = { true, false, false };
	return run_audio(engine, &aa, err);
}


bsk_status bsk_engine_audio_session_deactivated(bsk_engine *engine,
						bsk_error *err)
{
	struct audio_arg aa = { false, false, false };
	return run_audio(engine, &aa, err);
}


bsk_status bsk_engine_audio_route_changed(bsk_engine *engine, bsk_error *err)
{
	struct audio_arg aa = { engine ? engine->audio_active : false,
				true, false };
	return run_audio(engine, &aa, err);
}


bsk_status bsk_engine_audio_interruption(bsk_engine *engine, bool began,
					 bsk_error *err)
{
	struct audio_arg aa = { !began, false, began };
	return run_audio(engine, &aa, err);
}


size_t bsk_capabilities(char *buf, size_t buf_len)
{
	static const char caps[] =
		"sip.udp sip.tcp sip.tls sip.wss "
		"auth.md5 auth.sha256 "
		"reg.outbound reg.contact-params "
		"call.hold call.transfer.blind call.transfer.attended "
		"call.early-media "
		"dtmf.rfc4733 dtmf.sip-info "
		"nat.ice nat.stun nat.turn-udp "
		"media.srtp media.dtls-srtp "
		"codec.opus codec.g711 "
		"video.h264.videotoolbox:planned video.vp8:optional "
		"ice.restart:unsupported ice.trickle:unsupported "
		"tls.pinning:planned";
	size_t len = sizeof(caps) - 1;

	if (buf && buf_len) {
		size_t n = min(len, buf_len - 1);
		memcpy(buf, caps, n);
		buf[n] = '\0';
	}

	return len;
}
