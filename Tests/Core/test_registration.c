#include "test_common.h"

static struct waiter w;

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	record_event(&w, ev);
}

static int registered(struct waiter *x) { return x->reg_state == BSK_REG_REGISTERED; }
static int registered_twice(struct waiter *x) { return x->reg_count >= 2; }
static int registered_thrice(struct waiter *x) { return x->reg_count >= 3; }
static int failed(struct waiter *x) { return x->reg_state == BSK_REG_FAILED; }
static int running(struct waiter *x) { return x->engine_state == BSK_ENGINE_RUNNING; }


int main(int argc, char **argv)
{
	const char *host = argc > 1 ? argv[1] : "127.0.0.1";
	const char *port = argc > 2 ? argv[2] : "5080";
	const char *mode = argc > 3 ? argv[3] : "ok";
	bsk_engine_config cfg;
	bsk_account_config ac;
	bsk_engine *e = NULL;
	bsk_account_id acc = BSK_ID_NONE;
	bsk_error err;
	char aor[128], registrar[128];
	bsk_contact_param set_a[] = {
		{ "app-id", "com.example.proof" },
		{ "pn-type", "apple" },
		{ "pn-tok", "0000000000000000000000000000000000000000000000000000000000000001:remote&1111111111111111111111111111111111111111111111111111111111111111:voip" },
		{ "pn-silent", "1" },
		{ "pn-timeout", "0" },
		{ "pn-channel", "calls" },
	};
	bsk_contact_param set_b[] = {
		{ "app-id", "com.example.proof" },
		{ "pn-type", "apple" },
		{ "pn-tok", "2222222222222222222222222222222222222222222222222222222222222222:remote&3333333333333333333333333333333333333333333333333333333333333333:voip" },
		{ "pn-silent", "1" },
		{ "pn-timeout", "0" },
		{ "pn-channel", "calls" },
	};

	waiter_init(&w);

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.tls.verify_server = true;
	cfg.log_sip_trace = true;
	cfg.log_level = BSK_LOG_DEBUG;

	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &e, &err), &err);
	bsk_engine_set_log_handler(e, test_log, "reg ");
	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(wait_until(&w, running, 2000));

	snprintf(aor, sizeof(aor), "sip:alice@%s:%s", host, port);
	snprintf(registrar, sizeof(registrar), "sip:%s:%s;transport=udp", host, port);

	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.display_name = "Alice";
	ac.registrar = registrar;
	ac.transport = BSK_TRANSPORT_UDP;
	ac.auth_user = "alice";
	ac.auth_password = 0 == strcmp(mode, "badpass") ? "wrong" : "secret";
	ac.register_expires = 4;
	ac.contact_params = set_a;
	ac.contact_param_count = 6;

	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	CHECK_OK(bsk_account_register(e, acc, &err), &err);

	if (0 == strcmp(mode, "badpass")) {
		CHECK(wait_until(&w, failed, 5000));
		CHECK(w.last_error.status == BSK_ERR_AUTH);
		CHECK(w.last_error.sip_status == 401 ||
		      w.last_error.sip_status == 403);
		printf("registration badpass: PASS (%u %s)\n",
		       w.last_error.sip_status, w.last_error.sip_reason);
		goto done;
	}

	CHECK(wait_until(&w, registered, 5000));
	CHECK_OK(bsk_account_set_contact_params(e, acc, set_b, 6, true, &err),
		 &err);
	CHECK(wait_until(&w, registered_twice, 5000));
	CHECK(wait_until(&w, registered_thrice, 8000));
	CHECK_OK(bsk_account_unregister(e, acc, &err), &err);
	printf("registration: PASS (3 registrations, token update, "
	       "timer refresh, unregister)\n");

 done:
	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	return 0;
}
