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
	cfg.log_level = getenv("BSK_TEST_VERBOSE") ? BSK_LOG_DEBUG : BSK_LOG_INFO;
	cfg.log_sip_trace = true;
	cfg.extra_config = extra;
	cfg.rtp_port_min = 0 == strcmp(listen, "5070") ? 30000 : 40000;
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
	static const char *codecs[] = { "PCMU/8000/1" };

	snprintf(aor, sizeof(aor), "sip:%s@%s:%s", user, host, port);
	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.dtmf_mode = BSK_DTMF_RTP_EVENT;
	if (use_ice)
		ac.nat.mode = BSK_NAT_ICE;
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
	e = start_engine("5070");
	add_account(e, "bob", host, "5070");

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
		CHECK(w.ice_local_type == BSK_CAND_HOST);
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
	e = start_engine("5060");
	acc = add_account(e, "alice", host, "5060");

	snprintf(dest, sizeof(dest), "sip:bob@%s:5070", host);
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
		CHECK(w.ice_local_type == BSK_CAND_HOST);
		CHECK(w.ice_remote_type == BSK_CAND_HOST);

		sleep(1);
		CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
		rx_before = st.audio.rx_packets;
		__atomic_store_n(&ice_gather_n, 0, __ATOMIC_SEQ_CST);
		CHECK_OK(bsk_call_restart_ice(e, call, &err), &err);
		CHECK(wait_until(&w, ice_restarted, 15000));
		CHECK(w.ice_local_type == BSK_CAND_HOST);
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
	waiter_init(&w);
	if (0 == strcmp(role, "callee"))
		return run_callee(host);
	return run_caller(host);
}
