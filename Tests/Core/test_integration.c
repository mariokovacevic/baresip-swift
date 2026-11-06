#include <unistd.h>
#include "test_common.h"

static struct waiter w;
static struct waiter w2;
static int dtmf_via_info;

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	if (ev->type == BSK_EVENT_CALL_STATE)
		fprintf(stderr, "integration: call %llu state %d %s\n",
			(unsigned long long)ev->call, ev->u.call_state.state,
			ev->u.call_state.error.message);
	if (ev->type == BSK_EVENT_CALL_DTMF && ev->u.dtmf.via_sip_info)
		dtmf_via_info++;
	record_event(&w, ev);
}

static int running(struct waiter *x) { return x->engine_state == BSK_ENGINE_RUNNING; }
static int registered(struct waiter *x) { return x->reg_state == BSK_REG_REGISTERED; }
static int streams(struct waiter *x) { return x->call_state == BSK_CALL_STREAMS_RUNNING; }
static int early(struct waiter *x) { return x->call_state == BSK_CALL_EARLY_MEDIA; }
static int paused(struct waiter *x) { return x->call_state == BSK_CALL_PAUSED; }
static int released(struct waiter *x) { return x->released_call != BSK_ID_NONE; }
static int ice_connected(struct waiter *x) { return x->ice_state == BSK_ICE_CONNECTED; }
static int incoming(struct waiter *x) { return x->incoming_call != BSK_ID_NONE; }


static char *read_file(const char *path, size_t *len)
{
	FILE *f = fopen(path, "rb");
	char *buf;
	long n;

	if (!f)
		return NULL;
	fseek(f, 0, SEEK_END);
	n = ftell(f);
	fseek(f, 0, SEEK_SET);
	buf = calloc(1, (size_t)n + 1);
	if (fread(buf, 1, (size_t)n, f) != (size_t)n) {
		free(buf);
		fclose(f);
		return NULL;
	}
	fclose(f);
	*len = (size_t)n;
	return buf;
}


static const char *turn_transport = "udp";

static bsk_account_id add_account(bsk_engine *e, const char *host,
				  const char *user, const char *pass,
				  bool ice_turn, bsk_dtmf_mode dtmf)
{
	bsk_account_config ac;
	bsk_account_id acc = BSK_ID_NONE;
	bsk_error err;
	char aor[128], registrar[128], turn[128];
	bsk_turn_server turns[1];

	snprintf(aor, sizeof(aor), "sip:%s@%s", user, host);
	snprintf(registrar, sizeof(registrar), "sip:%s:5061;transport=tls", host);
	if (0 == strcmp(turn_transport, "tls"))
		snprintf(turn, sizeof(turn), "turns:%s:5349", host);
	else
		snprintf(turn, sizeof(turn), "turn:%s:3478?transport=%s", host,
			 turn_transport);

	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.registrar = registrar;
	ac.transport = BSK_TRANSPORT_TLS;
	ac.auth_user = user;
	ac.auth_password = pass;
	ac.register_expires = 60;
	ac.media_encryption = BSK_MEDIA_ENC_SRTP_OPTIONAL;
	ac.dtmf_mode = dtmf;
	if (ice_turn) {
		turns[0].uri = turn;
		turns[0].username = "bsk";
		turns[0].password = "bsk";
		ac.nat.mode = BSK_NAT_ICE;
		ac.nat.turn_servers = turns;
		ac.nat.turn_count = 1;
	}
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	return acc;
}


static void reset_call_state(void)
{
	pthread_mutex_lock(&w.mtx);
	w.call_state = -1;
	w.released_call = BSK_ID_NONE;
	w.incoming_call = BSK_ID_NONE;
	w.ice_state = -1;
	w.dtmf_count = 0;
	pthread_mutex_unlock(&w.mtx);
}


static int run_relay(const char *host, const char *ca, size_t ca_len)
{
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;
	bsk_account_id alice;
	bsk_call_id call = BSK_ID_NONE;
	bsk_call_statistics st;
	char dest[128];

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.tls.verify_server = true;
	cfg.tls.ca_pem = ca;
	cfg.tls.ca_pem_len = ca_len;
	cfg.log_level = BSK_LOG_INFO;
	cfg.ice_relay_only = true;

	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &e, &err), &err);
	bsk_engine_set_log_handler(e, test_log, "relay ");
	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(wait_until(&w, running, 2000));
	CHECK_OK(bsk_engine_audio_session_activated(e, &err), &err);

	printf("9. ICE relay-only policy over TURN/%s: media must flow "
	       "through the relay\n", turn_transport);
	alice = add_account(e, host, "alice", "alicepass", true, BSK_DTMF_AUTO);
	CHECK_OK(bsk_account_register(e, alice, &err), &err);
	CHECK(wait_until(&w, registered, 10000));
	snprintf(dest, sizeof(dest), "sip:echo@%s", host);
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call, &err), &err);
	CHECK(wait_until(&w, ice_connected, 20000));
	sleep(5);
	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	printf("   state=%d ice local=%d remote=%d %s -> %s tx=%u rx=%u\n",
	       w.call_state, st.local_candidate, st.remote_candidate,
	       st.local_address, st.remote_address, st.audio.tx_packets,
	       st.audio.rx_packets);
	CHECK(st.local_candidate == BSK_CAND_RELAY);
	CHECK(st.audio.tx_packets > 0);
	CHECK(st.audio.rx_packets > 0);
	CHECK(wait_until(&w, streams, 5000));

	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));
	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("integration relay (%s): PASS\n", turn_transport);
	return 0;
}


int main(int argc, char **argv)
{
	const char *host = argc > 1 ? argv[1] : "127.0.0.1";
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;
	bsk_account_id alice, bob;
	bsk_call_id call = BSK_ID_NONE, call2 = BSK_ID_NONE;
	bsk_call_statistics st;
	char dest[128];
	char *ca = NULL;
	size_t ca_len = 0;

	waiter_init(&w);
	waiter_init(&w2);

	ca = read_file(getenv("BSK_TEST_CA_PEM") ? getenv("BSK_TEST_CA_PEM") : "", &ca_len);
	CHECK(ca != NULL);

	if (argc > 3)
		turn_transport = argv[3];

	if (argc > 2 && 0 == strcmp(argv[2], "relay")) {
		int ret = run_relay(host, ca, ca_len);
		free(ca);
		return ret;
	}

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.tls.verify_server = true;
	cfg.tls.ca_pem = ca;
	cfg.tls.ca_pem_len = ca_len;
	cfg.log_sip_trace = getenv("BSK_TEST_VERBOSE") != NULL;
	setvbuf(stdout, NULL, _IOLBF, 0);
	cfg.log_level = BSK_LOG_INFO;
	cfg.max_calls = 4;

	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &e, &err), &err);
	bsk_engine_set_log_handler(e, test_log, "integration ");
	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(wait_until(&w, running, 2000));
	CHECK_OK(bsk_engine_audio_session_activated(e, &err), &err);

	printf("1. register alice over TLS with private CA\n");
	alice = add_account(e, host, "alice", "alicepass", false, BSK_DTMF_AUTO);
	CHECK_OK(bsk_account_register(e, alice, &err), &err);
	CHECK(wait_until(&w, registered, 10000));

	printf("2. audio call to echo, statistics\n");
	reset_call_state();
	snprintf(dest, sizeof(dest), "sip:echo@%s", host);
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call, &err), &err);
	CHECK(wait_until(&w, streams, 15000));
	sleep(3);
	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	CHECK(st.audio.tx_packets > 0 && st.audio.rx_packets > 0);
	printf("   tx=%u rx=%u jitter=%u ms secure=%d\n", st.audio.tx_packets,
	       st.audio.rx_packets, st.audio.rx_jitter_ms, st.audio.secure);

	printf("3. DTMF over RFC 4733 (auto mode negotiates telephone-event)\n");
	CHECK_OK(bsk_call_send_dtmf(e, call, "123", 120, 60, &err), &err);
	sleep(2);

	printf("4. hold and resume\n");
	CHECK_OK(bsk_call_hold(e, call, true, &err), &err);
	CHECK(wait_until(&w, paused, 10000));
	sleep(1);
	CHECK_OK(bsk_call_hold(e, call, false, &err), &err);
	CHECK(wait_until(&w, streams, 10000));
	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));

	printf("5. early media from the early extension\n");
	reset_call_state();
	snprintf(dest, sizeof(dest), "sip:early@%s", host);
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call, &err), &err);
	CHECK(wait_until(&w, early, 15000));
	CHECK(wait_until(&w, streams, 20000));
	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));

	printf("6. DTMF over SIP INFO\n");
	CHECK_OK(bsk_account_unregister(e, alice, &err), &err);
	CHECK_OK(bsk_account_remove(e, alice, &err), &err);
	alice = add_account(e, host, "alice", "alicepass", false, BSK_DTMF_SIP_INFO);
	pthread_mutex_lock(&w.mtx);
	w.reg_state = -1;
	pthread_mutex_unlock(&w.mtx);
	CHECK_OK(bsk_account_register(e, alice, &err), &err);
	CHECK(wait_until(&w, registered, 10000));
	reset_call_state();
	dtmf_via_info = 0;
	snprintf(dest, sizeof(dest), "sip:echo@%s", host);
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call, &err), &err);
	CHECK(wait_until(&w, streams, 15000));
	CHECK_OK(bsk_call_send_dtmf(e, call, "9", 120, 60, &err), &err);
	sleep(1);
	CHECK(dtmf_via_info == 1);
	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));

	printf("7. ICE with TURN relay\n");
	CHECK_OK(bsk_account_unregister(e, alice, &err), &err);
	CHECK_OK(bsk_account_remove(e, alice, &err), &err);
	alice = add_account(e, host, "alice", "alicepass", true, BSK_DTMF_AUTO);
	pthread_mutex_lock(&w.mtx);
	w.reg_state = -1;
	pthread_mutex_unlock(&w.mtx);
	CHECK_OK(bsk_account_register(e, alice, &err), &err);
	CHECK(wait_until(&w, registered, 10000));
	reset_call_state();
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call, &err), &err);
	CHECK(wait_until(&w, streams, 20000));
	CHECK(wait_until(&w, ice_connected, 20000));
	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	printf("   ice local=%d remote=%d %s -> %s\n", st.local_candidate,
	       st.remote_candidate, st.local_address, st.remote_address);
	CHECK_OK(bsk_call_hold(e, call, true, &err), &err);
	CHECK(wait_until(&w, paused, 10000));
	CHECK_OK(bsk_call_hold(e, call, false, &err), &err);
	CHECK(wait_until(&w, streams, 10000));

	printf("8. second account, second call, swap\n");
	bob = add_account(e, host, "bob", "bobpass", false, BSK_DTMF_AUTO);
	pthread_mutex_lock(&w.mtx);
	w.reg_state = -1;
	pthread_mutex_unlock(&w.mtx);
	CHECK_OK(bsk_account_register(e, bob, &err), &err);
	CHECK(wait_until(&w, registered, 10000));
	pthread_mutex_lock(&w.mtx);
	w.incoming_call = BSK_ID_NONE;
	pthread_mutex_unlock(&w.mtx);
	snprintf(dest, sizeof(dest), "sip:bob@%s", host);
	CHECK_OK(bsk_call_make(e, alice, dest, false, &call2, &err), &err);
	CHECK(wait_until(&w, incoming, 15000));
	CHECK_OK(bsk_call_answer(e, w.incoming_call, false, &err), &err);
	sleep(2);
	CHECK(bsk_call_list(e, NULL, 0) == 3);
	CHECK_OK(bsk_call_set_active(e, call, &err), &err);
	sleep(2);
	CHECK_OK(bsk_call_hangup(e, call2, &err), &err);
	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	sleep(2);
	CHECK(bsk_call_list(e, NULL, 0) <= 1);

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	free(ca);
	printf("integration: PASS\n");
	return 0;
}
