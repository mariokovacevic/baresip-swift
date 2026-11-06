#include <unistd.h>
#include "test_common.h"

static struct waiter w;
static const char *tag;
static int ice_gather_n;
static int ice_reconnected;

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	if (ev->type == BSK_EVENT_CALL_STATE)
		fprintf(stderr, "%s: call %llu state %d\n", tag,
			(unsigned long long)ev->call, ev->u.call_state.state);
	else if (ev->type == BSK_EVENT_CALL_MEDIA)
		fprintf(stderr, "%s: call %llu media %d\n", tag,
			(unsigned long long)ev->call, ev->u.media.event);
	else if (ev->type == BSK_EVENT_ICE) {
		if (ev->u.ice.state == BSK_ICE_GATHERING) {
			__atomic_add_fetch(&ice_gather_n, 1, __ATOMIC_SEQ_CST);
			__atomic_store_n(&ice_reconnected, 0, __ATOMIC_SEQ_CST);
		}
		else if (ev->u.ice.state == BSK_ICE_CONNECTED) {
			__atomic_store_n(&ice_reconnected, 1, __ATOMIC_SEQ_CST);
		}
	}
	record_event(&w, ev);
}

static int running(struct waiter *x) { return x->engine_state == BSK_ENGINE_RUNNING; }
static int incoming(struct waiter *x) { return x->incoming_call != BSK_ID_NONE; }
static int streams(struct waiter *x) { return x->call_state == BSK_CALL_STREAMS_RUNNING; }
static int paused(struct waiter *x) { return x->call_state == BSK_CALL_PAUSED; }
static int paused_remote(struct waiter *x) { return x->call_state == BSK_CALL_PAUSED_BY_REMOTE; }
static int released(struct waiter *x) { return x->released_call != BSK_ID_NONE; }
static int dtmf3(struct waiter *x) { return x->dtmf_count >= 3; }
static int ringing_or_later(struct waiter *x) { return x->call_state >= BSK_CALL_OUTGOING_RINGING; }
static int ice_connected(struct waiter *x) { return x->ice_state == BSK_ICE_CONNECTED; }
static bool use_ice;
static const char *turn_transport;
static const char *turn_host;
static char *ca_pem;
static size_t ca_len;
static int expected_type = BSK_CAND_HOST;
static const char *caller_port = "5060";
static const char *callee_port = "5070";


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
	if (buf && fread(buf, 1, (size_t)n, f) != (size_t)n) {
		free(buf);
		buf = NULL;
	}
	fclose(f);
	*len = (size_t)n;
	return buf;
}

static int ice_restarted(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&ice_gather_n, __ATOMIC_SEQ_CST) >= 1 &&
	       __atomic_load_n(&ice_reconnected, __ATOMIC_SEQ_CST);
}


static bsk_engine *start_engine(const char *listen)
{
	static char extra[128];
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;

	snprintf(extra, sizeof(extra), "sip_listen\t\t0.0.0.0:%s", listen);

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.tls.verify_server = true;
	if (turn_transport) {
		cfg.tls.ca_pem = ca_pem;
		cfg.tls.ca_pem_len = ca_len;
		cfg.ice_relay_only = true;
	}
	cfg.log_level = getenv("BSK_TEST_VERBOSE") ? BSK_LOG_DEBUG : BSK_LOG_INFO;
	cfg.log_sip_trace = true;
	cfg.extra_config = extra;
	cfg.rtp_port_min = 0 == strcmp(listen, callee_port) ? 30000 : 40000;
	cfg.rtp_port_max = cfg.rtp_port_min + 100;

	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &e, &err), &err);
	bsk_engine_set_log_handler(e, test_log, (void *)tag);
	CHECK_OK(bsk_engine_start(e, &err), &err);
	CHECK(wait_until(&w, running, 2000));
	CHECK_OK(bsk_engine_audio_session_activated(e, &err), &err);

	return e;
}


static bsk_account_id add_account(bsk_engine *e, const char *user,
				  const char *host, const char *port)
{
	bsk_account_config ac;
	bsk_account_id acc = BSK_ID_NONE;
	bsk_error err;
	char aor[128];
	static char turn[128];
	static bsk_turn_server turns[1];
	static const char *codecs[] = { "PCMU/8000/1" };

	snprintf(aor, sizeof(aor), "sip:%s@%s:%s", user, host, port);
	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.dtmf_mode = BSK_DTMF_RTP_EVENT;
	if (use_ice)
		ac.nat.mode = BSK_NAT_ICE;
	if (turn_transport) {
		if (0 == strcmp(turn_transport, "tls"))
			snprintf(turn, sizeof(turn), "turns:%s:5349", turn_host);
		else
			snprintf(turn, sizeof(turn),
				 "turn:%s:3478?transport=%s", turn_host,
				 turn_transport);
		turns[0].uri = turn;
		turns[0].username = "bsk";
		turns[0].password = "bsk";
		ac.nat.turn_servers = turns;
		ac.nat.turn_count = 1;
	}
	ac.audio_codecs = codecs;
	ac.audio_codec_count = 1;
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	return acc;
}


static int run_callee(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_call_info info;
	bsk_call_statistics st;

	tag = "callee";
	e = start_engine(callee_port);
	add_account(e, "bob", host, callee_port);

	printf("READY\n");
	fflush(stdout);

	CHECK(wait_until(&w, incoming, 15000));
	CHECK(BSK_OK == bsk_call_get_info(e, w.incoming_call, &info));
	CHECK(info.state == BSK_CALL_INCOMING);
	CHECK(strstr(info.remote_uri, "alice") != NULL);
	CHECK(!info.outgoing);

	CHECK_OK(bsk_call_answer(e, w.incoming_call, false, &err), &err);
	CHECK(wait_until(&w, streams, 10000));
	if (use_ice) {
		CHECK(wait_until(&w, ice_connected, 10000));
		CHECK(w.ice_local_type == expected_type);
		CHECK(BSK_OK == bsk_call_get_statistics(e, w.incoming_call, &st));
		CHECK(st.ice_state == BSK_ICE_CONNECTED);
		CHECK(strlen(st.remote_address) > 0);
		__atomic_store_n(&ice_gather_n, 0, __ATOMIC_SEQ_CST);
		CHECK(wait_until(&w, ice_restarted, 15000));
		printf("callee: ICE restart: PASS\n");
		fflush(stdout);
	}

	CHECK(wait_until(&w, paused_remote, 10000));
	CHECK(wait_until(&w, streams, 10000));

	CHECK(wait_until(&w, dtmf3, 15000));
	CHECK(0 == strncmp(w.dtmf, "12#", 3));

	CHECK(BSK_OK == bsk_call_get_statistics(e, w.incoming_call, &st));
	CHECK(st.audio.rx_packets > 0);

	CHECK(wait_until(&w, released, 15000));
	CHECK(bsk_call_list(e, NULL, 0) == 0);

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("callee: PASS (dtmf=%s, rx=%u pkts, mos=%.2f)\n", w.dtmf,
	       st.audio.rx_packets, st.audio.rtt_ms ? st.mos_estimate :
	       st.mos_estimate);
	return 0;
}


static int run_peer(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_call_statistics st;
	int timeout_s = getenv("BSK_PEER_TIMEOUT") ?
		atoi(getenv("BSK_PEER_TIMEOUT")) : 300;

	tag = "peer";
	e = start_engine(callee_port);
	add_account(e, "bob", host, callee_port);

	printf("READY\n");
	fflush(stdout);

	CHECK(wait_until(&w, incoming, timeout_s * 1000));
	CHECK_OK(bsk_call_answer(e, w.incoming_call, false, &err), &err);
	CHECK(wait_until(&w, streams, 15000));
	printf("peer: call answered\n");
	fflush(stdout);
	sleep(2);
	CHECK(BSK_OK == bsk_call_get_statistics(e, w.incoming_call, &st));
	CHECK(wait_until(&w, released, 120000));

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("peer: PASS (rx=%u pkts, tx=%u pkts)\n", st.audio.rx_packets,
	       st.audio.tx_packets);
	return 0;
}


static int run_caller(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_account_id acc;
	bsk_call_id call = BSK_ID_NONE;
	bsk_call_info info;
	bsk_call_statistics st;
	uint32_t rx_before = 0;
	char dest[128];

	tag = "caller";
	e = start_engine(caller_port);
	acc = add_account(e, "alice", host, caller_port);

	snprintf(dest, sizeof(dest), "sip:bob@%s:%s", host, callee_port);
	CHECK_OK(bsk_call_make(e, acc, dest, false, &call, &err), &err);
	CHECK(call != BSK_ID_NONE);
	CHECK(bsk_call_list(e, NULL, 0) == 1);
	CHECK(wait_until(&w, ringing_or_later, 10000));
	CHECK(wait_until(&w, streams, 10000));

	CHECK(BSK_OK == bsk_call_get_info(e, call, &info));
	CHECK(info.outgoing);
	CHECK(0 == strcmp(info.audio_codec, "PCMU"));
	if (use_ice) {
		CHECK(wait_until(&w, ice_connected, 10000));
		CHECK(w.ice_local_type == expected_type);
		CHECK(w.ice_remote_type == expected_type);

		sleep(1);
		CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
		rx_before = st.audio.rx_packets;
		__atomic_store_n(&ice_gather_n, 0, __ATOMIC_SEQ_CST);
		CHECK_OK(bsk_call_restart_ice(e, call, &err), &err);
		CHECK(wait_until(&w, ice_restarted, 15000));
		CHECK(w.ice_local_type == expected_type);
		sleep(2);
		CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
		CHECK(st.ice_state == BSK_ICE_CONNECTED);
		CHECK(st.audio.rx_packets > rx_before + 25);
		printf("caller: ICE restart: PASS (rx %u -> %u)\n", rx_before,
		       st.audio.rx_packets);
		fflush(stdout);
	}

	sleep(1);
	CHECK_OK(bsk_call_hold(e, call, true, &err), &err);
	CHECK(wait_until(&w, paused, 10000));
	CHECK(BSK_OK == bsk_call_get_info(e, call, &info));
	CHECK(info.audio_dir == BSK_DIR_SENDONLY ||
	      info.audio_dir == BSK_DIR_INACTIVE);
	sleep(1);
	CHECK_OK(bsk_call_hold(e, call, false, &err), &err);
	CHECK(wait_until(&w, streams, 10000));

	CHECK_OK(bsk_call_set_microphone_muted(e, call, true, &err), &err);
	CHECK_OK(bsk_call_set_microphone_muted(e, call, false, &err), &err);

	CHECK_OK(bsk_call_send_dtmf(e, call, "12#", 120, 60, &err), &err);
	CHECK(BSK_ERR_BUSY == bsk_call_send_dtmf(e, call, "4", 0, 0, &err));
	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_send_dtmf(e, call, "x", 0, 0, &err) ||
	      err.status == BSK_ERR_BUSY);
	sleep(2);

	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	CHECK(st.audio.tx_packets > 0);

	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));
	CHECK(BSK_ERR_NOT_FOUND == bsk_call_hangup(e, call, &err));

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("caller: PASS (tx=%u pkts, codec=%s)\n", st.audio.tx_packets,
	       info.audio_codec);
	return 0;
}


int main(int argc, char **argv)
{
	const char *role = argc > 1 ? argv[1] : "caller";
	const char *host = argc > 2 ? argv[2] : "127.0.0.1";

	use_ice = argc > 3 && 0 == strcmp(argv[3], "ice");
	turn_transport = getenv("BSK_TEST_TURN");
	if (turn_transport && use_ice) {
		turn_host = host;
		expected_type = BSK_CAND_RELAY;
		caller_port = "5260";
		callee_port = "5270";
		ca_pem = read_file(getenv("BSK_TEST_CA_PEM") ?
				   getenv("BSK_TEST_CA_PEM") : "", &ca_len);
		CHECK(ca_pem != NULL);
	}
	else {
		turn_transport = NULL;
	}
	waiter_init(&w);
	if (0 == strcmp(role, "callee"))
		return run_callee(host);
	if (0 == strcmp(role, "peer"))
		return run_peer(host);
	return run_caller(host);
}
