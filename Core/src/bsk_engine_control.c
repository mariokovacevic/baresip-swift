#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include "bsk_internal.h"
#include "bsk_engine_internal.h"


static int reregister_all_op(bsk_engine *e, void *arg)
{
	struct le *le;
	int err = 0;
	(void)arg;

	for (le = e->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;

		if (a->removing || a->unregistered)
			continue;
		if (account_regint(ua_account(a->ua)))
			err = bsk_first_error(err, ua_register(a->ua));
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


static bool local_address_handler(const char *ifname, const struct sa *sa,
				  void *arg)
{
	struct network *net = arg;

	if (net_ifaddr_filter(net, ifname, sa))
		(void)net_add_address_ifname(net, sa, ifname);

	return false;
}


static int network_op(bsk_engine *e, void *arg)
{
	struct net_arg *na = arg;
	struct network *net = baresip_network();
	bsk_event ev;
	int err;

	(void)net_flush_addresses(net);
	(void)net_if_apply(local_address_handler, net);
	net_dns_refresh(net);

	err = 0;
	if (!e->tls_configured) {
		err = uag_reset_transp(false, false);
		err = bsk_first_error(err, bsk_engine_apply_tls(e));
	}
	if (!err)
		err = uag_reset_transp(na->reregister, na->update_calls);

	bsk_event_init(&ev, BSK_EVENT_NETWORK);
	ev.u.network.transports_reset = (err == 0);
	{
		const struct sa *laddr =
			net_laddr_af(baresip_network(), AF_INET);
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
	struct audio_arg aa = { engine ? engine->audio_active : false, true,
				false };
	return run_audio(engine, &aa, err);
}


bsk_status bsk_engine_audio_interruption(bsk_engine *engine, bool began,
					 bsk_error *err)
{
	struct audio_arg aa = { !began, false, began };
	return run_audio(engine, &aa, err);
}
