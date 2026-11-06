#include <stddef.h>
#include <unistd.h>
#include "test_common.h"
#include "../../Core/src/bsk_rate.h"

size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len);


static void test_contact_params(void)
{
	bsk_contact_param p[] = {
		{ "app-id", "com.example.app" },
		{ "pn-type", "apple" },
		{ "pn-tok", "0123456789abcdef:remote&fedcba9876543210:voip" },
		{ "pn-silent", "1" },
		{ "pn-timeout", "0" },
		{ "flag", NULL },
	};
	bsk_contact_param bad_sep[] = { { "pn-tok", "a;b" } };
	bsk_contact_param bad_eq[] = { { "pn-tok", "a=b" } };
	bsk_contact_param bad_space[] = { { "pn-tok", "a b" } };
	bsk_contact_param bad_name[] = { { "pn tok", "a" } };
	bsk_contact_param empty_name[] = { { "", "a" } };
	char buf[256];
	size_t len = 0;

	CHECK(BSK_OK ==
	      bsk_contact_params_encode(p, 6, buf, sizeof(buf), &len));
	CHECK(0 ==
	      strcmp(buf,
		     "app-id=com.example.app;pn-type=apple;"
		     "pn-tok=0123456789abcdef:remote&fedcba9876543210:voip;"
		     "pn-silent=1;pn-timeout=0;flag"));
	CHECK(len == strlen(buf));

	CHECK(BSK_OK == bsk_contact_params_encode(p, 6, NULL, 0, &len));
	CHECK(len == strlen(buf));

	CHECK(BSK_ERR_BUFFER_TOO_SMALL ==
	      bsk_contact_params_encode(p, 6, buf, len, NULL));
	CHECK(BSK_OK == bsk_contact_params_encode(p, 6, buf, len + 1, NULL));

	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_contact_params_encode(bad_sep, 1, buf, sizeof(buf), NULL));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_contact_params_encode(bad_eq, 1, buf, sizeof(buf), NULL));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_contact_params_encode(bad_space, 1, buf, sizeof(buf), NULL));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_contact_params_encode(bad_name, 1, buf, sizeof(buf), NULL));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_contact_params_encode(empty_name, 1, buf, sizeof(buf), NULL));

	CHECK(BSK_OK ==
	      bsk_contact_params_encode(NULL, 0, buf, sizeof(buf), &len));
	CHECK(len == 0 && buf[0] == '\0');
}


static void test_redaction(void)
{
	const char *in =
		"Authorization: Digest username=\"alice\", realm=\"r\", "
		"nonce=\"n\", uri=\"sip:x\", response=\"deadbeefdeadbeef\", "
		"algorithm=MD5\r\n"
		"Contact: <sip:a@h;pn-tok=0123456789abcdef0123:remote&"
		"ffffffffffffffff:voip;pn-silent=1>\r\n"
		"auth_pass=secret;stunpass=s2";
	char out[512];
	size_t n = bsk_redact(in, strlen(in), out, sizeof(out));

	CHECK(n > 0);
	CHECK(strstr(out, "deadbeef") == NULL);
	CHECK(strstr(out, "response=\"[redacted]\"") != NULL);
	CHECK(strstr(out, "pn-tok=01234567[redacted];pn-silent=1") != NULL);
	CHECK(strstr(out, "ffffffff") == NULL);
	CHECK(strstr(out, "auth_pass=[redacted];") != NULL);
	CHECK(strstr(out, "stunpass=[redacted]") != NULL);
	CHECK(strstr(out, "secret") == NULL);
	CHECK(strstr(out, "username=\"alice\"") != NULL);
}


static void test_status_strings(void)
{
	CHECK(0 == strcmp(bsk_status_string(BSK_OK), "ok"));
	CHECK(0 ==
	      strcmp(bsk_status_string(BSK_ERR_AUTH), "authentication failed"));
	CHECK(bsk_abi_version() == 6);
	CHECK(bsk_capabilities(NULL, 0) > 0);
}


struct hammer_arg {
	bsk_engine *e;
	int calls;
	int stop;
};


static void *hammer(void *arg)
{
	struct hammer_arg *ha = arg;
	bsk_error err;

	while (!__atomic_load_n(&ha->stop, __ATOMIC_SEQ_CST)) {
		(void)bsk_account_register(ha->e, 999, &err);
		__atomic_add_fetch(&ha->calls, 1, __ATOMIC_SEQ_CST);
	}

	return NULL;
}


static void test_engine_lifecycle_without_network(void)
{
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;
	bsk_account_id acc = BSK_ID_NONE;

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.tls.verify_server = true;
	cfg.extra_config = "sip_listen\t\t0.0.0.0:0";

	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_engine_create(NULL, NULL, NULL, &e, &err));
	CHECK_OK(bsk_engine_create(&cfg, NULL, NULL, &e, &err), &err);
	CHECK(bsk_engine_get_state(e) == BSK_ENGINE_IDLE);

	CHECK(BSK_ERR_INVALID_STATE == bsk_account_add(e, NULL, &acc, &err) ||
	      BSK_ERR_INVALID_ARGUMENT == err.status);

	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(bsk_engine_get_state(e) == BSK_ENGINE_READY ||
	      bsk_engine_get_state(e) == BSK_ENGINE_RUNNING);
	CHECK(!bsk_engine_is_engine_thread(e));
	CHECK(BSK_ERR_INVALID_STATE == bsk_engine_start(e, &err));

	{
		bsk_account_config ac;
		bsk_registration_state rs;
		memset(&ac, 0, sizeof(ac));
		ac.aor = "sip:alice@example.invalid";
		ac.auth_user = "alice";
		ac.auth_password = "secret";
		CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
		CHECK(acc != BSK_ID_NONE);
		CHECK(BSK_OK ==
		      bsk_account_get_registration_state(e, acc, &rs));
		CHECK(rs == BSK_REG_NONE);
		CHECK(BSK_ERR_NOT_FOUND ==
		      bsk_account_get_registration_state(e, 999, &rs));
		CHECK_OK(bsk_account_remove(e, acc, &err), &err);
		CHECK(BSK_ERR_NOT_FOUND == bsk_account_remove(e, acc, &err));

		ac.aor = "sip:alice@example.invalid>;answermode=auto";
		CHECK(BSK_ERR_INVALID_ARGUMENT ==
		      bsk_account_add(e, &ac, &acc, &err));
		ac.aor = "sip:alice@example.invalid";
		ac.display_name = "x\" <sip:a@b>;answermode=auto";
		CHECK(BSK_ERR_INVALID_ARGUMENT ==
		      bsk_account_add(e, &ac, &acc, &err));
		ac.display_name = "Alice Example";
		CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
		CHECK_OK(bsk_account_remove(e, acc, &err), &err);
	}

	CHECK(bsk_call_list(e, NULL, 0) == 0);

	CHECK_OK(bsk_engine_stop(e, 2000, &err), &err);
	CHECK(bsk_engine_get_state(e) == BSK_ENGINE_STOPPED);
	CHECK_OK(bsk_engine_stop(e, 2000, &err), &err);

	CHECK_OK(bsk_engine_start(e, &err), &err);
	{
		pthread_t t;
		struct hammer_arg ha = { e, 0, 0 };

		CHECK(0 == pthread_create(&t, NULL, hammer, &ha));
		while (!__atomic_load_n(&ha.calls, __ATOMIC_SEQ_CST))
			usleep(1000);
		CHECK_OK(bsk_engine_stop(e, 2000, &err), &err);
		__atomic_store_n(&ha.stop, 1, __ATOMIC_SEQ_CST);
		CHECK(0 == pthread_join(t, NULL));
		CHECK(BSK_OK != bsk_call_hangup(e, 1, &err));
	}

	bsk_engine_destroy(e);
	bsk_engine_destroy(NULL);
}


static void test_config_size_compat(void)
{
	bsk_engine_config cfg = BSK_ENGINE_CONFIG_INIT;
	bsk_engine *e = NULL;
	bsk_error err;
	bsk_account_config ac = BSK_ACCOUNT_CONFIG_INIT;
	bsk_account_id acc = BSK_ID_NONE;
	struct {
		bsk_engine_config cfg;
		uint8_t future_fields[64];
	} big;

	CHECK(cfg.size == sizeof(bsk_engine_config));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.extra_config = "sip_listen\t\t0.0.0.0:0";

	memset(&big, 0xAB, sizeof(big));
	big.cfg = cfg;
	big.cfg.size = (uint32_t)sizeof(big);
	CHECK_OK(bsk_engine_create(&big.cfg, NULL, NULL, &e, &err), &err);
	CHECK_OK(bsk_engine_start(e, &err), &err);

	ac.aor = "sip:alice@example.invalid";
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	CHECK(acc != BSK_ID_NONE);

	CHECK_OK(bsk_engine_stop(e, 2000, &err), &err);
	bsk_engine_destroy(e);

	cfg.size = (uint32_t)offsetof(bsk_engine_config, ice_relay_only);
	CHECK_OK(bsk_engine_create(&cfg, NULL, NULL, &e, &err), &err);
	bsk_engine_destroy(e);
}


static void test_rate_control(void)
{
	struct bsk_rate r;
	uint32_t sent = 0, b;
	int32_t lost = 0;
	uint64_t now = 0;
	int i;

	bsk_rate_init(&r, 800000, 150000, 800000, now);
	CHECK(r.current == 800000);
	CHECK(bsk_rate_update(&r, sent, lost, now) == 800000);

	sent += 10;
	now += 1000;
	CHECK(bsk_rate_update(&r, sent, lost, now) == 800000);

	sent += 100;
	lost += 30;
	now += 1000;
	b = bsk_rate_update(&r, sent, lost, now);
	CHECK(b < 800000 && b >= 150000);
	CHECK(b == 690910);

	for (i = 0; i < 20; i++) {
		sent += 100;
		lost += 50;
		now += 1000;
		b = bsk_rate_update(&r, sent, lost, now);
	}
	CHECK(b == 150000);

	sent += 100;
	lost += 5;
	now += 1000;
	CHECK(bsk_rate_update(&r, sent, lost, now) == 150000);

	for (i = 0; i < 200; i++) {
		sent += 100;
		now += 1000;
		b = bsk_rate_update(&r, sent, lost, now);
	}
	CHECK(b == 800000);

	bsk_rate_set_max(&r, 300000);
	CHECK(r.current == 300000);
	bsk_rate_set_max(&r, 100000);
	CHECK(r.current == 100000 && r.min == 100000);

	bsk_rate_init(&r, 0, 900000, 500000, 0);
	CHECK(r.current == 500000 && r.min == 500000);

	bsk_rate_init(&r, 500000, 150000, 800000, 0);
	(void)bsk_rate_update(&r, 1000, 10, 0);
	CHECK(bsk_rate_update(&r, 500, 0, 1000) == 500000);
	CHECK(bsk_rate_update(&r, 600, 0, 5000) > 500000);
}


int main(void)
{
	test_contact_params();
	test_redaction();
	test_status_strings();
	test_engine_lifecycle_without_network();
	test_config_size_compat();
	test_rate_control();
	printf("unit: PASS\n");
	return 0;
}
