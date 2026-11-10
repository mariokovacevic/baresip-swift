#include <stddef.h>
#include <unistd.h>
#include "test_common.h"
#include "../../Core/src/bsk_rate.h"
#include "../../Core/src/bsk_h264.h"

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
		"auth_pass=secret;stunpass=s2\r\n"
		"a=crypto:1 AES_CM_128_HMAC_SHA1_80 "
		"inline:WVNfX19zZW1jdGwgKCkgewkyMjA7fQp9CnVubGVz|2^20|1:32\r\n";
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
	CHECK(strstr(out, "WVNfX19") == NULL);
	CHECK(strstr(out, "inline:[redacted]|2^20|1:32") != NULL);
}


static void test_redaction_of_call_secrets(void)
{
	const char *in =
		"a=ice-ufrag:abcd\r\na=ice-pwd:0123456789abcdefghij\r\n"
		"Signal=7\r\nDuration=160\r\n"
		"audio: send DTMF digit: '4'\n"
		"received in-band DTMF event: '9' (end=0)\n"
		"To: <sip:alice:hunter2@example.com;transport=tls>\r\n"
		"Contact: <sips:bob@example.com:5061>\r\n"
		"Via: SIP/2.0/UDP 192.0.2.1:5060;branch=z9hG4bK1\r\n";
	char out[512];
	size_t n = bsk_redact(in, strlen(in), out, sizeof(out));

	CHECK(n > 0);
	CHECK(strstr(out, "0123456789abcdefghij") == NULL);
	CHECK(strstr(out, "a=ice-pwd:[redacted]\r\n") != NULL);
	CHECK(strstr(out, "a=ice-ufrag:abcd") != NULL);
	CHECK(strstr(out, "Signal=[redacted]\r\nDuration=160") != NULL);
	CHECK(strstr(out, "DTMF digit: '[redacted]'") != NULL);
	CHECK(strstr(out, "DTMF event: '[redacted]' (end=0)") != NULL);
	CHECK(strstr(out, "hunter2") == NULL);
	CHECK(strstr(out, "<sip:alice:[redacted]@example.com;transport=tls>") !=
	      NULL);
	CHECK(strstr(out, "<sips:bob@example.com:5061>") != NULL);
	CHECK(strstr(out, "192.0.2.1:5060;branch=z9hG4bK1") != NULL);
}


static bool has_capability(const char *caps, const char *name)
{
	size_t len = strlen(name);
	const char *p = caps;

	while ((p = strstr(p, name)) != NULL) {
		bool starts = p == caps || p[-1] == ' ';
		bool ends = p[len] == '\0' || p[len] == ' ';

		if (starts && ends)
			return true;
		p += len;
	}

	return false;
}


static void test_capabilities(void)
{
	char caps[1024];
	static const char *implemented[] = {
		"ice.restart",
		"tls.pinning",
		"video.h264.videotoolbox",
		"nat.turn-tcp",
		"nat.turn-tls",
		"message.sip",
		"call.recording",
		"call.transfer.attended",
		"call.no-audio",
		"call.headers",
		"nat.rtcp-mux",
		"nat.pinhole",
		"codec.g722",
		"video.picture-update.sip-info",
	};
	size_t i;

	CHECK(bsk_capabilities(caps, sizeof(caps)) < sizeof(caps));
	for (i = 0; i < sizeof(implemented) / sizeof(implemented[0]); i++)
		CHECK(has_capability(caps, implemented[i]));
	CHECK(!has_capability(caps, "ice.restart:unsupported"));
}


static void test_status_strings(void)
{
	CHECK(0 == strcmp(bsk_status_string(BSK_OK), "ok"));
	CHECK(0 ==
	      strcmp(bsk_status_string(BSK_ERR_AUTH), "authentication failed"));
	CHECK(bsk_abi_version() == 8);
	CHECK(bsk_capabilities(NULL, 0) > 0);
	test_capabilities();
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
		{
			bsk_account_id ids[2] = { 0, 0 };
			bsk_registration_state states[2] = { BSK_REG_FAILED,
							     BSK_REG_FAILED };

			CHECK(1 == bsk_account_list(e, NULL, NULL, 0));
			CHECK(1 == bsk_account_list(e, ids, states, 2));
			CHECK(ids[0] == acc && states[0] == BSK_REG_NONE);
		}
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


static void base_config(bsk_engine_config *cfg)
{
	memset(cfg, 0, sizeof(*cfg));
	cfg->modules = test_modules;
	cfg->module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg->audio.source_module = "ausine";
	cfg->audio.player_module = "aufile";
	cfg->audio.player_device = "/dev/null";
	cfg->extra_config = "sip_listen\t\t0.0.0.0:0";
}


static bsk_status create_status(const bsk_engine_config *cfg)
{
	bsk_engine *e = NULL;
	bsk_error err;
	bsk_status st = bsk_engine_create(cfg, NULL, NULL, &e, &err);

	bsk_engine_destroy(e);
	return st;
}


static void test_config_validation(void)
{
	static const char *good_pin[] = {
		"47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="
	};
	static const char *empty_pin[] = { "" };
	static const char *short_pin[] = { "47DEQpj8HBSa" };
	static const char *not_base64[] = {
		"47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuF!="
	};
	static const char *bad_module[] = { "g711", "ice\nice_policy all" };
	static const char *bad_codec[] = { "PCMU\nx" };
	static const char *long_codecs[40];
	bsk_engine_config cfg;
	size_t i;

	base_config(&cfg);
	CHECK(BSK_OK == create_status(&cfg));

	cfg.tls.pinned_spki_sha256_base64 = good_pin;
	cfg.tls.pinned_count = 1;
	CHECK(BSK_OK == create_status(&cfg));
	cfg.tls.insecure_skip_verify = true;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	cfg.tls.insecure_skip_verify = false;
	cfg.tls.pinned_spki_sha256_base64 = empty_pin;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	cfg.tls.pinned_spki_sha256_base64 = short_pin;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	cfg.tls.pinned_spki_sha256_base64 = not_base64;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	cfg.tls.pinned_spki_sha256_base64 = NULL;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	base_config(&cfg);
	cfg.modules = bad_module;
	cfg.module_count = 2;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	base_config(&cfg);
	cfg.audio.player_device = "/dev/null\nice_policy\tall";
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	{
		static char long_device[400];
		static char too_long_device[1100];

		memset(long_device, 'a', sizeof(long_device) - 1);
		memset(too_long_device, 'a', sizeof(too_long_device) - 1);
		base_config(&cfg);
		cfg.audio.player_device = long_device;
		CHECK(BSK_OK == create_status(&cfg));
		cfg.audio.player_device = too_long_device;
		CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	}

	base_config(&cfg);
	cfg.audio.source_module = "ausine,x";
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	base_config(&cfg);
	cfg.video.source_device = "front\rcamera";
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	base_config(&cfg);
	cfg.network_interface = "en0\nsip_verify_server no";
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	cfg.network_interface = "en0";
	CHECK(BSK_OK == create_status(&cfg));

	base_config(&cfg);
	cfg.audio.codecs = bad_codec;
	cfg.audio.codec_count = 1;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
	for (i = 0; i < 40; i++)
		long_codecs[i] = "opus/48000/2";
	cfg.audio.codecs = long_codecs;
	cfg.audio.codec_count = 40;
	CHECK(BSK_OK != create_status(&cfg));

	base_config(&cfg);
	cfg.user_agent = "Agent\r\nX-Injected: 1";
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));

	base_config(&cfg);
	cfg.rtp_port_min = 20000;
	cfg.rtp_port_max = 10000;
	CHECK(BSK_ERR_INVALID_ARGUMENT == create_status(&cfg));
}


static bsk_status add_status(bsk_engine *e, const bsk_account_config *ac)
{
	bsk_account_id id = BSK_ID_NONE;
	bsk_error err;
	bsk_status st = bsk_account_add(e, ac, &id, &err);

	if (st == BSK_OK)
		CHECK_OK(bsk_account_remove(e, id, &err), &err);

	return st;
}


static void test_text_validation(void)
{
	static const char *bad_header[] = { "X-Id\r\nX-Other" };
	bsk_engine_config cfg;
	bsk_account_config ac;
	bsk_engine *e = NULL;
	bsk_account_id acc = BSK_ID_NONE;
	bsk_call_id call = BSK_ID_NONE;
	uint64_t message = 0;
	bsk_error err;

	base_config(&cfg);
	CHECK_OK(bsk_engine_create(&cfg, NULL, NULL, &e, &err), &err);
	CHECK_OK(bsk_engine_start(e, &err), &err);

	memset(&ac, 0, sizeof(ac));
	ac.aor = "sip:alice@example.invalid";
	ac.transport = BSK_TRANSPORT_TLS;
	CHECK(BSK_OK == add_status(e, &ac));

	ac.aor = "sip:alice@example.invalid?transport=udp";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.aor = "sip:alice@example.invalid";

	ac.registrar = "sip:example.invalid";
	CHECK(BSK_OK == add_status(e, &ac));
	ac.registrar = "sip:example.invalid;transport=tls";
	CHECK(BSK_OK == add_status(e, &ac));
	ac.registrar = "sip:example.invalid;transport=udp";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.registrar = "sip:example.invalid?x=y";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.registrar = "sip:example.invalid\r\nX-Injected: 1";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.registrar = NULL;

	ac.outbound_proxy = "sip:proxy.example.invalid;transport=tcp";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.outbound_proxy = NULL;

	ac.auth_user = "alice\r\nX-Injected: 1";
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.auth_user = NULL;

	ac.incoming_headers = bad_header;
	ac.incoming_header_count = 1;
	CHECK(BSK_ERR_INVALID_ARGUMENT == add_status(e, &ac));
	ac.incoming_headers = NULL;
	ac.incoming_header_count = 0;

	ac.transport = BSK_TRANSPORT_UDP;
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);

	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_make(e, acc, "sip:bob@example.invalid\r\nX-Injected: 1",
			    false, &call, &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_message_send(e, acc,
			       "sip:bob@example.invalid>\r\nX-Injected: <1",
			       "hello", &message, &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_reject(e, 1, 486, "Busy\r\nX-Injected: 1", &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_reject(e, 1, 200, "OK", &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_transfer(e, 1, "sip:c@example.invalid\r\nX: 1", &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_account_set_credentials(e, acc, "a\nb", "secret", &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
		      bsk_call_send_dtmf(e, 1, "1", 60000, 0, &err) ||
	      BSK_ERR_NOT_FOUND == err.status);

	CHECK_OK(bsk_engine_stop(e, 2000, &err), &err);
	bsk_engine_destroy(e);
}


static void test_single_running_engine(void)
{
	bsk_engine_config cfg;
	bsk_engine *first = NULL;
	bsk_engine *second = NULL;
	bsk_error err;

	base_config(&cfg);
	CHECK_OK(bsk_engine_create(&cfg, NULL, NULL, &first, &err), &err);
	CHECK_OK(bsk_engine_create(&cfg, NULL, NULL, &second, &err), &err);

	CHECK_OK(bsk_engine_start(first, &err), &err);
	CHECK(BSK_ERR_BUSY == bsk_engine_start(second, &err));
	CHECK(bsk_engine_get_state(second) == BSK_ENGINE_IDLE);

	CHECK_OK(bsk_engine_stop(first, 2000, &err), &err);
	CHECK_OK(bsk_engine_start(second, &err), &err);
	CHECK(BSK_ERR_BUSY == bsk_engine_start(first, &err));

	bsk_engine_destroy(second);
	CHECK_OK(bsk_engine_start(first, &err), &err);
	bsk_engine_destroy(first);
}


static int stop_events;
static int stop_on_engine_thread;


static void stop_handler(bsk_engine *e, const bsk_event *ev, void *user)
{
	(void)user;

	if (ev->type != BSK_EVENT_ENGINE_STATE ||
	    ev->u.engine.state != BSK_ENGINE_STOPPED)
		return;

	__atomic_add_fetch(&stop_events, 1, __ATOMIC_SEQ_CST);
	if (bsk_engine_is_engine_thread(e))
		__atomic_add_fetch(&stop_on_engine_thread, 1, __ATOMIC_SEQ_CST);
}


static void *stopper(void *arg)
{
	bsk_error err;

	(void)bsk_engine_stop(arg, 2000, &err);
	return NULL;
}


static void test_concurrent_stop(void)
{
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;
	pthread_t threads[4];
	size_t i;

	base_config(&cfg);
	CHECK_OK(bsk_engine_create(&cfg, stop_handler, NULL, &e, &err), &err);
	CHECK_OK(bsk_engine_start(e, &err), &err);

	for (i = 0; i < 4; i++)
		CHECK(0 == pthread_create(&threads[i], NULL, stopper, e));
	for (i = 0; i < 4; i++)
		CHECK(0 == pthread_join(threads[i], NULL));

	CHECK(bsk_engine_get_state(e) == BSK_ENGINE_STOPPED);
	CHECK(__atomic_load_n(&stop_events, __ATOMIC_SEQ_CST) == 1);
	CHECK(__atomic_load_n(&stop_on_engine_thread, __ATOMIC_SEQ_CST) == 1);
	bsk_engine_destroy(e);
}


static int h264_put(struct bsk_h264_depack *d, const uint8_t *payload,
		    size_t len, uint16_t seq, bool marker, bool *complete)
{
	struct mbuf *pkt = mbuf_alloc(len);
	int err;

	CHECK(pkt != NULL);
	CHECK(0 == mbuf_write_mem(pkt, payload, len));
	pkt->pos = 0;
	err = bsk_h264_depack_put(d, pkt, seq, marker, complete);
	mem_deref(pkt);

	return err;
}


static bool h264_unit_is(const struct bsk_h264_depack *d, const uint8_t *want,
			 size_t len)
{
	return d->mb->end == len && 0 == memcmp(d->mb->buf, want, len);
}


static void test_h264_depacketizer(void)
{
	static const uint8_t single[] = { 0x65, 0xaa, 0xbb };
	static const uint8_t single_unit[] = { 0, 0, 1, 0x65, 0xaa, 0xbb };
	static const uint8_t fu_start[] = { 0x7c, 0x85, 0x11, 0x12 };
	static const uint8_t fu_middle[] = { 0x7c, 0x05, 0x13, 0x14 };
	static const uint8_t fu_end[] = { 0x7c, 0x45, 0x15, 0x16 };
	static const uint8_t fu_unit[] = { 0,    0,    1,    0x65, 0x11,
					   0x12, 0x13, 0x14, 0x15, 0x16 };
	static const uint8_t forbidden[] = { 0xe5, 0x01 };
	static const uint8_t unknown[] = { 0x7e, 0x01 };
	uint8_t big[1400];
	struct bsk_h264_depack d;
	bool complete = true;
	size_t i;
	int err = 0;

	CHECK(0 == bsk_h264_depack_init(&d));

	CHECK(0 == h264_put(&d, single, sizeof(single), 1, true, &complete));
	CHECK(complete);
	CHECK(h264_unit_is(&d, single_unit, sizeof(single_unit)));
	bsk_h264_depack_reset(&d);

	CHECK(0 ==
	      h264_put(&d, fu_start, sizeof(fu_start), 2, false, &complete));
	CHECK(!complete);
	CHECK(0 ==
	      h264_put(&d, fu_middle, sizeof(fu_middle), 3, false, &complete));
	CHECK(0 == h264_put(&d, fu_end, sizeof(fu_end), 4, true, &complete));
	CHECK(complete);
	CHECK(h264_unit_is(&d, fu_unit, sizeof(fu_unit)));
	bsk_h264_depack_reset(&d);

	CHECK(0 ==
	      h264_put(&d, fu_start, sizeof(fu_start), 10, false, &complete));
	CHECK(0 ==
	      h264_put(&d, fu_middle, sizeof(fu_middle), 12, false, &complete));
	CHECK(0 == h264_put(&d, fu_end, sizeof(fu_end), 13, true, &complete));
	CHECK(!complete);
	CHECK(d.n_lost == 2);
	CHECK(d.mb->end == 0);
	CHECK(0 == h264_put(&d, single, sizeof(single), 14, true, &complete));
	CHECK(complete);
	CHECK(h264_unit_is(&d, single_unit, sizeof(single_unit)));
	bsk_h264_depack_reset(&d);

	CHECK(0 == h264_put(&d, single, sizeof(single), 20, false, &complete));
	CHECK(0 ==
	      h264_put(&d, fu_start, sizeof(fu_start), 21, false, &complete));
	CHECK(0 == h264_put(&d, single, sizeof(single), 22, true, &complete));
	CHECK(complete);
	CHECK(d.mb->end == 2 * sizeof(single_unit));
	bsk_h264_depack_reset(&d);

	CHECK(EPROTO ==
	      h264_put(&d, fu_start, sizeof(fu_start), 30, true, &complete));
	CHECK(!complete);
	CHECK(d.mb->end == 0 && !d.frag);

	CHECK(EBADMSG ==
	      h264_put(&d, forbidden, sizeof(forbidden), 31, true, &complete));
	CHECK(EBADMSG ==
	      h264_put(&d, unknown, sizeof(unknown), 32, true, &complete));
	CHECK(0 != h264_put(&d, fu_start, 1, 33, true, &complete));
	CHECK(0 != h264_put(&d, single, 0, 34, true, &complete));
	CHECK(!complete);

	memset(big, 0x55, sizeof(big));
	big[0] = 0x41;
	for (i = 0; i < 2 * BSK_H264_MAX_UNIT / sizeof(big) && !err; i++)
		err = h264_put(&d, big, sizeof(big), (uint16_t)(40 + i), false,
			       &complete);
	CHECK(err == ENOMEM);
	CHECK(i > BSK_H264_MAX_UNIT / (sizeof(big) + 3));
	CHECK(d.mb->end == 0);

	CHECK(0 == h264_put(&d, single, sizeof(single), 9000, true, &complete));
	CHECK(complete);
	CHECK(h264_unit_is(&d, single_unit, sizeof(single_unit)));

	bsk_h264_depack_close(&d);
	CHECK(d.mb == NULL);
	CHECK(EINVAL ==
	      h264_put(&d, single, sizeof(single), 9001, true, &complete));
}


static void test_h264_access_unit(void)
{
	static const uint8_t stap[] = { 0x78, 0x00, 0x04, 0x67, 0x42, 0xe0,
					0x1f, 0x00, 0x02, 0x68, 0xce };
	static const uint8_t idr[] = { 0x65, 0x21, 0x22, 0x23 };
	static const uint8_t slice[] = { 0x41, 0x31 };
	static const uint8_t sei[] = { 0x06, 0x05, 0x01 };
	static const uint8_t avcc_key[] = {
		0, 0, 0, 4, 0x65, 0x21, 0x22, 0x23
	};
	static const uint8_t avcc_delta[] = { 0, 0, 0, 2, 0x41, 0x31 };
	uint8_t long_sps[3 + BSK_H264_MAX_PARAM_SET + 1];
	struct bsk_h264_depack d;
	struct bsk_h264_unit unit;
	struct mbuf *avcc = mbuf_alloc(64);
	bool complete = false;

	CHECK(avcc != NULL);
	CHECK(0 == bsk_h264_depack_init(&d));

	CHECK(0 == h264_put(&d, stap, sizeof(stap), 1, false, &complete));
	CHECK(0 == h264_put(&d, sei, sizeof(sei), 2, false, &complete));
	CHECK(0 == h264_put(&d, idr, sizeof(idr), 3, true, &complete));
	CHECK(complete);
	CHECK(0 == bsk_h264_annexb_to_avcc(d.mb->buf, d.mb->end, avcc, &unit));
	CHECK(unit.sps_len == 4 && 0 == memcmp(unit.sps, stap + 3, 4));
	CHECK(unit.pps_len == 2 && 0 == memcmp(unit.pps, stap + 9, 2));
	CHECK(unit.have_slice && unit.keyframe);
	CHECK(avcc->end == sizeof(avcc_key));
	CHECK(0 == memcmp(avcc->buf, avcc_key, sizeof(avcc_key)));
	bsk_h264_depack_reset(&d);
	mbuf_rewind(avcc);

	CHECK(0 == h264_put(&d, slice, sizeof(slice), 4, true, &complete));
	CHECK(0 == bsk_h264_annexb_to_avcc(d.mb->buf, d.mb->end, avcc, &unit));
	CHECK(!unit.sps && !unit.pps);
	CHECK(unit.have_slice && !unit.keyframe);
	CHECK(avcc->end == sizeof(avcc_delta));
	CHECK(0 == memcmp(avcc->buf, avcc_delta, sizeof(avcc_delta)));
	mbuf_rewind(avcc);

	memset(long_sps, 0x55, sizeof(long_sps));
	long_sps[0] = 0;
	long_sps[1] = 0;
	long_sps[2] = 1;
	long_sps[3] = 0x67;
	CHECK(0 ==
	      bsk_h264_annexb_to_avcc(long_sps, sizeof(long_sps), avcc, &unit));
	CHECK(!unit.sps && !unit.have_slice && avcc->end == 0);

	CHECK(0 == bsk_h264_annexb_to_avcc(long_sps, 2, avcc, &unit));
	CHECK(!unit.have_slice);
	CHECK(0 == bsk_h264_annexb_to_avcc(long_sps, 3, avcc, &unit));
	CHECK(!unit.have_slice && avcc->end == 0);
	CHECK(EINVAL == bsk_h264_annexb_to_avcc(NULL, 4, avcc, &unit));

	bsk_h264_depack_close(&d);
	mem_deref(avcc);
}


int main(void)
{
	test_contact_params();
	test_redaction();
	test_redaction_of_call_secrets();
	test_config_validation();
	test_text_validation();
	test_single_running_engine();
	test_concurrent_stop();
	test_status_strings();
	test_engine_lifecycle_without_network();
	test_config_size_compat();
	test_rate_control();
	test_h264_depacketizer();
	test_h264_access_unit();
	printf("unit: PASS\n");
	return 0;
}
