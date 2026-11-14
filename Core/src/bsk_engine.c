#include <string.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include "bsk_internal.h"
#include "bsk_engine_internal.h"


static bsk_engine *g_engine;
static _Atomic(bsk_engine *) g_owner;


static bool claim_owner(bsk_engine *engine)
{
	bsk_engine *expected = NULL;

	return atomic_compare_exchange_strong(&g_owner, &expected, engine) ||
	       expected == engine;
}


static void release_owner(bsk_engine *engine)
{
	bsk_engine *expected = engine;

	(void)atomic_compare_exchange_strong(&g_owner, &expected, NULL);
}


bsk_engine *bsk_global_engine(void)
{
	return g_engine;
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
	bool tracked;

	if (!engine || !ev)
		return;

	tracked = bsk_on_engine_thread(engine);
	mtx_lock(&engine->cb_mtx);
	if (tracked)
		engine->emit_depth++;
	if (engine->handler)
		engine->handler(engine, ev, engine->user);
	if (tracked)
		engine->emit_depth--;
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
	case BEVENT_AUDIO_ERROR: bsk_call_handle_event(e, ev, event); break;

	case BEVENT_MODULE:
		bsk_call_handle_module_event(e, bevent_get_text(event));
		break;

	case BEVENT_SIPSESS_CONN: bsk_call_handle_invite(e, event); break;

	default: break;
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
	e->emit_depth = 0;
	e->replace_pending = false;
	e->replace_confirmed = false;
	e->replace_call = NULL;
	e->tls_configured = NULL;
	e->video_inflight = 0;
	bsk_log_init(e);

	mb = mbuf_alloc(2048);
	if (!mb) {
		err = ENOMEM;
		goto fail;
	}

	err = bsk_engine_build_config(e, mb);
	if (err)
		goto fail;

	err = conf_configure_buf(mb->buf, mb->end);
	if (err)
		goto fail;

	cfg = conf_config();
	if (str_isset(e->instance_uuid))
		str_ncpy(cfg->sip.uuid, e->instance_uuid,
			 sizeof(cfg->sip.uuid));

	err = baresip_init(cfg);
	if (err)
		goto fail;

	err = ua_init(str_isset(e->user_agent)
			      ? e->user_agent
			      : "BaresipKit/" BSK_VERSION_STRING,
		      true, true, true);
	if (err)
		goto fail;

	err = bsk_engine_apply_tls(e);
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

	err = bsk_message_init(e);
	if (err)
		goto fail;

	err = bsk_audio_init();
	if (err)
		goto fail;

	bsk_g722_init();

	err = bsk_record_init();
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
	bsk_record_close();
	bsk_message_close(e);
	bevent_unregister(bevent_handler);
	bsk_video_close(e);
	bsk_calls_flush(e);
	bsk_audio_close();
	bsk_g722_close();
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
	set_state(e, BSK_ENGINE_STOPPED, NULL);

	mtx_lock(&e->mtx);
	e->stop_done = true;
	cnd_broadcast(&e->cnd);
	mtx_unlock(&e->mtx);

	return 0;

fail:
	bsk_record_close();
	bsk_message_close(e);
	bevent_unregister(bevent_handler);
	bsk_video_close(e);
	bsk_audio_close();
	bsk_g722_close();
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
	mtx_init(&e->life_mtx, mtx_plain);
	cnd_init(&e->cnd);
	cnd_init(&e->video_cnd);

	{
		bsk_engine_config local;
		size_t n = config->size ? config->size : sizeof(local);

		if (n > sizeof(local))
			n = sizeof(local);
		memset(&local, 0, sizeof(local));
		memcpy(&local, config, n);
		local.size = (uint32_t)sizeof(local);
#ifndef BSK_ALLOW_INSECURE_TLS
		if (local.tls.insecure_skip_verify) {
			bsk_engine_destroy(e);
			return bsk_error_set(
				err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0, NULL,
				"insecure_skip_verify needs a core "
				"built with BSK_ALLOW_INSECURE_TLS");
		}
#endif
		if (local.tls.min_version &&
		    local.tls.min_version != BSK_TLS_VERSION_1_2 &&
		    local.tls.min_version != BSK_TLS_VERSION_1_3) {
			bsk_engine_destroy(e);
			return bsk_error_set(
				err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0, NULL,
				"tls.min_version 0x%04x is not TLS 1.2 or 1.3",
				(unsigned)local.tls.min_version);
		}
		if (str_isset(local.extra_config) &&
		    bsk_extra_config_tls_key(local.extra_config)) {
			const char *key =
				bsk_extra_config_tls_key(local.extra_config);

			bsk_engine_destroy(e);
			return bsk_error_set(
				err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0, NULL,
				"extra_config may not set %s", key);
		}
		if (local.session_min_se &&
		    local.session_min_se < BSK_SESSION_TIMER_MIN) {
			bsk_engine_destroy(e);
			return bsk_error_set(
				err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0, NULL,
				"session_min_se %u s is below "
				"the RFC 4028 minimum of %u s",
				local.session_min_se, BSK_SESSION_TIMER_MIN);
		}
		if (local.session_expires &&
		    bsk_session_min_se(&local) > local.session_expires) {
			bsk_engine_destroy(e);
			return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT,
					     EINVAL, 0, NULL,
					     "session_min_se %u s is longer "
					     "than session_expires %u s",
					     bsk_session_min_se(&local),
					     local.session_expires);
		}
		ret = bsk_engine_copy_config(e, &local);
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


void bsk_engine_set_event_handler(bsk_engine *engine, bsk_event_handler handler,
				  void *user)
{
	if (!engine)
		return;

	mtx_lock(&engine->cb_mtx);
	engine->handler = handler;
	engine->user = user;
	mtx_unlock(&engine->cb_mtx);
}


static bsk_status start_locked(bsk_engine *engine, bsk_error *err)
{
	int ret;

	if (engine->state != BSK_ENGINE_IDLE &&
	    engine->state != BSK_ENGINE_STOPPED &&
	    engine->state != BSK_ENGINE_FAILED)
		return bsk_error_set(err, BSK_ERR_INVALID_STATE, EALREADY, 0,
				     NULL, "engine already started");

	if (!claim_owner(engine))
		return bsk_error_set(err, BSK_ERR_BUSY, EBUSY, 0, NULL,
				     "only one engine may run per process");

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
		release_owner(engine);
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
		release_owner(engine);
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "engine start failed: %m", ret);
	}

	return BSK_OK;
}


bsk_status bsk_engine_start(bsk_engine *engine, bsk_error *err)
{
	bsk_status status;

	bsk_error_clear(err);

	if (!engine)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	if (bsk_on_engine_thread(engine))
		return bsk_error_set(err, BSK_ERR_INVALID_STATE, EINVAL, 0,
				     NULL,
				     "start must not be called from the "
				     "engine thread");

	mtx_lock(&engine->life_mtx);
	status = start_locked(engine, err);
	mtx_unlock(&engine->life_mtx);

	return status;
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
	bsk_calls_hangup_account(e, BSK_ID_NONE);
	ua_stop_all(false);
	bsk_accounts_flush(e);
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
				     NULL,
				     "stop must not be called from the "
				     "engine thread");

	mtx_lock(&engine->life_mtx);
	if (engine->thread_valid) {
		if (engine->state == BSK_ENGINE_READY ||
		    engine->state == BSK_ENGINE_RUNNING)
			(void)bsk_run(engine, stop_op, &sa);

		thrd_join(engine->thread, NULL);
		engine->thread_valid = false;
		engine->state = BSK_ENGINE_STOPPED;
		release_owner(engine);
	}
	mtx_unlock(&engine->life_mtx);

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
	mem_deref(engine->hold_pcm);
	mem_deref(engine->cipher_list);
	if (engine->ca_pem)
		mem_deref(engine->ca_pem);
	if (engine->client_cert_pem) {
		memset(engine->client_cert_pem, 0, engine->client_cert_pem_len);
		mem_deref(engine->client_cert_pem);
	}
	cnd_destroy(&engine->video_cnd);
	cnd_destroy(&engine->cnd);
	mtx_destroy(&engine->life_mtx);
	mtx_destroy(&engine->video_mtx);
	mtx_destroy(&engine->cb_mtx);
	mtx_destroy(&engine->mtx);
	free(engine);
}


#ifdef BSK_TEST_HOOKS
int bsk_test_session_timer(bsk_engine *engine, uint32_t expires,
			   uint32_t min_se);


int bsk_test_session_timer(bsk_engine *engine, uint32_t expires,
			   uint32_t min_se)
{
	if (!engine || engine->thread_valid || min_se > expires)
		return EINVAL;

	engine->session_expires = expires;
	engine->session_min_se = min_se;
	return 0;
}
#endif


bsk_engine_state bsk_engine_get_state(const bsk_engine *engine)
{
	return engine ? (bsk_engine_state)engine->state : BSK_ENGINE_IDLE;
}
