#include <unistd.h>
#include "test_common.h"

static struct waiter w;

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	record_event(&w, ev);
}

static int registered_twice(struct waiter *x)
{
	return x->reg_count >= 2;
}
static int registered_thrice(struct waiter *x)
{
	return x->reg_count >= 3;
}
static int failed(struct waiter *x)
{
	return x->reg_state == BSK_REG_FAILED;
}
static int unregistered(struct waiter *x)
{
	return x->reg_state == BSK_REG_NONE;
}

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
	bool tls = 0 == strncmp(mode, "tls", 3);
	bool slow =
		0 == strcmp(mode, "reregister") || 0 == strcmp(mode, "overlap");
	char *ca_pem = NULL;
	size_t ca_len = 0;
	const char *pins[1] = { getenv("BSK_TEST_PIN") };
	const char *bad_pins[1] = {
		"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
	};
	bsk_contact_param set_a[] = {
		{ "app-id", "com.example.proof" },
		{ "pn-type", "apple" },
		{ "pn-tok",
		  "0000000000000000000000000000000000000000000000000000000000000001:remote&1111111111111111111111111111111111111111111111111111111111111111:voip" },
		{ "pn-silent", "1" },
		{ "pn-timeout", "0" },
		{ "pn-channel", "calls" },
	};
	bsk_contact_param set_b[] = {
		{ "app-id", "com.example.proof" },
		{ "pn-type", "apple" },
		{ "pn-tok",
		  "2222222222222222222222222222222222222222222222222222222222222222:remote&3333333333333333333333333333333333333333333333333333333333333333:voip" },
		{ "pn-silent", "1" },
		{ "pn-timeout", "0" },
		{ "pn-channel", "calls" },
	};

	bsk_contact_param set_c[] = {
		{ "app-id", "com.example.proof" },
		{ "pn-type", "apple" },
		{ "pn-tok",
		  "4444444444444444444444444444444444444444444444444444444444444444:remote&5555555555555555555555555555555555555555555555555555555555555555:voip" },
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
	cfg.log_sip_trace = true;
	cfg.log_level = BSK_LOG_DEBUG;

	if (tls && 0 != strcmp(mode, "tls-noca") &&
	    0 != strncmp(mode, "tls-system", 10)) {
		ca_pem = read_file(getenv("BSK_TEST_CA_PEM"), &ca_len);
		CHECK(ca_pem != NULL);
		cfg.tls.ca_pem = ca_pem;
		cfg.tls.ca_pem_len = ca_len;
	}
	if (0 == strcmp(mode, "tls-pin-ok") ||
	    0 == strcmp(mode, "tls-system-pin-ok")) {
		CHECK(pins[0] != NULL);
		cfg.tls.pinned_spki_sha256_base64 = pins;
		cfg.tls.pinned_count = 1;
	}
	if (0 == strcmp(mode, "tls-pin-bad") ||
	    0 == strcmp(mode, "tls-system-pin-bad")) {
		cfg.tls.pinned_spki_sha256_base64 = bad_pins;
		cfg.tls.pinned_count = 1;
	}

	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &e, &err), &err);
	bsk_engine_set_log_handler(e, test_log, "reg ");
	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(wait_until(&w, running, 2000));

	snprintf(aor, sizeof(aor), "sip:alice@%s:%s", host, port);
	if (0 == strcmp(mode, "tls-bare"))
		snprintf(registrar, sizeof(registrar), "sip:%s:%s", host, port);
	else
		snprintf(registrar, sizeof(registrar), "sip:%s:%s;transport=%s",
			 host, port, tls ? "tls" : "udp");

	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.display_name = "Alice";
	ac.registrar = registrar;
	ac.transport = tls ? BSK_TRANSPORT_TLS : BSK_TRANSPORT_UDP;
	ac.auth_user = "alice";
	ac.auth_password = 0 == strcmp(mode, "badpass") ? "wrong" : "secret";
	ac.register_expires = 4;
	ac.contact_params = set_a;
	ac.contact_param_count = 6;

	if (slow)
		ac.register_expires = 60;

	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	CHECK_OK(bsk_account_register(e, acc, &err), &err);

	if (0 == strcmp(mode, "reregister")) {
		CHECK_OK(bsk_account_register(e, acc, &err), &err);
		CHECK_OK(bsk_engine_network_changed(e, true, true, &err), &err);
		CHECK(wait_until(&w, registered, 5000));
		usleep(1500 * 1000);
		CHECK(w.reg_state == BSK_REG_REGISTERED);
		CHECK_OK(bsk_account_unregister(e, acc, &err), &err);
		CHECK(wait_until(&w, unregistered, 3000));
		usleep(600 * 1000);
		printf("registration reregister: PASS (registered again "
		       "during an unanswered REGISTER)\n");
		goto done;
	}

	if (0 == strcmp(mode, "overlap")) {
		CHECK(wait_until(&w, registered, 5000));
		CHECK_OK(bsk_account_set_contact_params(e, acc, set_b, 6, true,
							&err),
			 &err);
		CHECK_OK(bsk_account_set_contact_params(e, acc, set_c, 6, true,
							&err),
			 &err);
		CHECK_OK(bsk_account_register(e, acc, &err), &err);
		usleep(2500 * 1000);
		CHECK(w.reg_state == BSK_REG_REGISTERED);
		CHECK_OK(bsk_account_unregister(e, acc, &err), &err);
		CHECK(wait_until(&w, unregistered, 3000));
		usleep(600 * 1000);
		printf("registration overlap: PASS (parameters updated and "
		       "registered again during an unanswered REGISTER)\n");
		goto done;
	}

	if (0 == strcmp(mode, "tls-pin-bad") || 0 == strcmp(mode, "tls-noca") ||
	    0 == strcmp(mode, "tls-system-pin-bad")) {
		CHECK(wait_until(&w, failed, 15000));
		CHECK(w.last_error.sip_status == 0);
		CHECK(w.last_error.status == BSK_ERR_TLS);
		printf("registration %s: PASS (rejected: %s)\n", mode,
		       w.last_error.message);
		goto done;
	}

	if (0 == strcmp(mode, "tls")) {
		bsk_registration_state state = BSK_REG_REGISTERED;
		int count;

		CHECK(wait_until(&w, registered, 10000));
		CHECK_OK(bsk_engine_network_changed(e, true, true, &err), &err);
		CHECK(wait_until(&w, registered_twice, 10000));
		CHECK_OK(bsk_account_unregister(e, acc, &err), &err);
		CHECK(wait_until(&w, unregistered, 2000));
		count = w.reg_count;
		CHECK_OK(bsk_engine_network_changed(e, true, true, &err), &err);
		CHECK_OK(bsk_engine_resume(e, &err), &err);
		CHECK_OK(bsk_engine_prepare_for_push_wakeup(e, &err), &err);
		usleep(1500 * 1000);
		CHECK(BSK_OK ==
		      bsk_account_get_registration_state(e, acc, &state));
		CHECK(state == BSK_REG_NONE);
		CHECK(w.reg_state == BSK_REG_NONE && w.reg_count == count);
		printf("registration tls: PASS (registered over TLS, again "
		       "after a network change, stays unregistered)\n");
		goto done;
	}

	if (tls) {
		CHECK(wait_until(&w, registered, 10000));
		CHECK_OK(bsk_account_unregister(e, acc, &err), &err);
		CHECK(wait_until(&w, unregistered, 2000));
		printf("registration %s: PASS (registered over TLS)\n", mode);
		goto done;
	}

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
	free(ca_pem);
	return 0;
}
