#include <unistd.h>
#include "test_common.h"

enum { LISTEN_PORT = 5090 };

static struct waiter w;
static bsk_engine *engine;
static const char *mode;
static int transfer_events;
static int incoming_count;
static int connected_count;
static int released_count;
static int outgoing_seen;
static int reentrant_status = -1;
static bsk_call_id last_incoming;
static struct {
	char digit;
	bool end;
	bool via_sip_info;
} dtmf_events[8];
static int dtmf_event_count;


static bool mode_is(const char *name)
{
	return 0 == strcmp(mode, name);
}


static void on_incoming(const bsk_event *ev)
{
	bsk_error err;

	__atomic_add_fetch(&incoming_count, 1, __ATOMIC_SEQ_CST);
	__atomic_store_n(&last_incoming, ev->call, __ATOMIC_SEQ_CST);

	if (mode_is("dtmf"))
		CHECK_OK(bsk_call_answer(engine, ev->call, false, &err), &err);
	else if (mode_is("reentrant") && incoming_count == 1)
		(void)bsk_call_reject(engine, ev->call, 486, "Busy Here", &err);
	else if (mode_is("reentrant"))
		CHECK_OK(bsk_call_answer(engine, ev->call, false, &err), &err);
}


static void on_call_state(const bsk_event *ev)
{
	bsk_error err;
	bsk_call_state state = ev->u.call_state.state;

	if (state == BSK_CALL_OUTGOING_INIT)
		__atomic_store_n(&outgoing_seen, 1, __ATOMIC_SEQ_CST);
	if (state == BSK_CALL_CONNECTED)
		__atomic_add_fetch(&connected_count, 1, __ATOMIC_SEQ_CST);
	if (state == BSK_CALL_RELEASED)
		__atomic_add_fetch(&released_count, 1, __ATOMIC_SEQ_CST);
	if (mode_is("reentrant") &&
	    (state == BSK_CALL_ENDED || state == BSK_CALL_FAILED)) {
		bsk_status st = bsk_call_hangup(engine, ev->call, &err);

		__atomic_store_n(&reentrant_status, (int)st, __ATOMIC_SEQ_CST);
	}
}


static void on_dtmf(const bsk_event *ev)
{
	int n = __atomic_load_n(&dtmf_event_count, __ATOMIC_SEQ_CST);

	if (n >= (int)(sizeof(dtmf_events) / sizeof(dtmf_events[0])))
		return;

	dtmf_events[n].digit = ev->u.dtmf.digit;
	dtmf_events[n].end = ev->u.dtmf.end;
	dtmf_events[n].via_sip_info = ev->u.dtmf.via_sip_info;
	__atomic_store_n(&dtmf_event_count, n + 1, __ATOMIC_SEQ_CST);
}


static void on_event(bsk_engine *e, const bsk_event *ev, void *user)
{
	(void)e;
	(void)user;

	if (ev->type == BSK_EVENT_CALL_DTMF)
		on_dtmf(ev);

	if (ev->type == BSK_EVENT_CALL_INCOMING)
		on_incoming(ev);
	else if (ev->type == BSK_EVENT_CALL_STATE)
		on_call_state(ev);
	else if (ev->type == BSK_EVENT_CALL_TRANSFER)
		__atomic_add_fetch(&transfer_events, 1, __ATOMIC_SEQ_CST);

	record_event(&w, ev);
}


static int running(struct waiter *x)
{
	return x->engine_state == BSK_ENGINE_RUNNING;
}


static int has_incoming(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&incoming_count, __ATOMIC_SEQ_CST) >= 1;
}


static int has_second_incoming(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&incoming_count, __ATOMIC_SEQ_CST) >= 2;
}


static int has_connected(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&connected_count, __ATOMIC_SEQ_CST) >= 1;
}


static int one_released(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&released_count, __ATOMIC_SEQ_CST) >= 1;
}


static int two_released(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&released_count, __ATOMIC_SEQ_CST) >= 2;
}


static bsk_account_id start(const char *host, bool early_media)
{
	static char extra[64];
	static char aor[128];
	bsk_engine_config cfg;
	bsk_account_config ac;
	bsk_account_id acc = BSK_ID_NONE;
	bsk_error err;

	snprintf(extra, sizeof(extra), "sip_listen\t\t0.0.0.0:%d", LISTEN_PORT);
	snprintf(aor, sizeof(aor), "sip:bob@%s", host);

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.log_level =
		getenv("BSK_TEST_VERBOSE") ? BSK_LOG_DEBUG : BSK_LOG_INFO;
	cfg.log_sip_trace = true;
	cfg.extra_config = extra;

	waiter_init(&w);
	CHECK_OK(bsk_engine_create(&cfg, on_event, NULL, &engine, &err), &err);
	bsk_engine_set_log_handler(engine, test_log, (void *)"victim");
	CHECK_OK(bsk_engine_start(engine, &err), &err);
	CHECK(wait_until(&w, running, 5000));

	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.answer_early_media = early_media;
	CHECK_OK(bsk_account_add(engine, &ac, &acc, &err), &err);
	CHECK_OK(bsk_engine_audio_session_activated(engine, &err), &err);

	printf("READY\n");
	fflush(stdout);
	return acc;
}


static void finish(const char *summary)
{
	bsk_error err;

	CHECK_OK(bsk_engine_stop(engine, 2000, &err), &err);
	bsk_engine_destroy(engine);
	printf("victim %s: PASS (%s)\n", mode, summary);
}


static int run_refer_ringing(const char *host)
{
	bsk_error err;

	(void)start(host, false);
	CHECK(wait_until(&w, has_incoming, 15000));
	usleep(1500 * 1000);
	CHECK(bsk_call_list(engine, NULL, 0) == 1);
	CHECK(!__atomic_load_n(&outgoing_seen, __ATOMIC_SEQ_CST));
	CHECK(!__atomic_load_n(&transfer_events, __ATOMIC_SEQ_CST));
	CHECK_OK(bsk_call_answer(engine, last_incoming, false, &err), &err);
	CHECK(wait_until(&w, has_connected, 5000));
	CHECK(wait_until(&w, one_released, 10000));
	CHECK(!__atomic_load_n(&outgoing_seen, __ATOMIC_SEQ_CST));
	finish("REFER on a ringing call declined, the call still answers");
	return 0;
}


static int run_fake_replace(const char *host)
{
	bsk_error err;

	(void)start(host, false);
	CHECK(wait_until(&w, has_incoming, 15000));
	CHECK_OK(bsk_call_answer(engine, last_incoming, false, &err), &err);
	CHECK(wait_until(&w, one_released, 10000));
	CHECK(wait_until(&w, has_second_incoming, 10000));
	CHECK(wait_until(&w, two_released, 10000));
	CHECK(__atomic_load_n(&connected_count, __ATOMIC_SEQ_CST) == 1);
	finish("a call after a forged replaced reason keeps ringing");
	return 0;
}


static int run_reentrant(const char *host)
{
	(void)start(host, true);
	CHECK(wait_until(&w, one_released, 15000));
	CHECK(wait_until(&w, has_connected, 10000));
	CHECK(wait_until(&w, two_released, 10000));
	CHECK(__atomic_load_n(&reentrant_status, __ATOMIC_SEQ_CST) ==
	      BSK_ERR_NOT_FOUND);
	CHECK(bsk_call_list(engine, NULL, 0) == 0);
	finish("reject and hangup from the event callback");
	return 0;
}


static int run_remove_live(const char *host, bool stop)
{
	bsk_account_id acc = start(host, false);
	bsk_call_info info;
	bsk_error err;

	CHECK(wait_until(&w, has_incoming, 15000));
	CHECK_OK(bsk_call_answer(engine, last_incoming, false, &err), &err);
	CHECK(wait_until(&w, has_connected, 5000));
	usleep(300 * 1000);

	if (stop) {
		CHECK_OK(bsk_engine_stop(engine, 2000, &err), &err);
		CHECK(__atomic_load_n(&released_count, __ATOMIC_SEQ_CST) == 1);
		CHECK(w.engine_state == BSK_ENGINE_STOPPED);
		CHECK(BSK_OK !=
		      bsk_call_get_info(engine, last_incoming, &info));
		bsk_engine_destroy(engine);
		printf("victim %s: PASS (stop ends the live call)\n", mode);
		return 0;
	}

	CHECK_OK(bsk_account_remove(engine, acc, &err), &err);
	CHECK(__atomic_load_n(&released_count, __ATOMIC_SEQ_CST) == 1);
	CHECK(BSK_ERR_NOT_FOUND ==
	      bsk_call_get_info(engine, last_incoming, &info));
	CHECK(bsk_call_list(engine, NULL, 0) == 0);
	usleep(500 * 1000);
	finish("removing the account ends its live call");
	return 0;
}


static int four_dtmf_events(struct waiter *x)
{
	(void)x;
	return __atomic_load_n(&dtmf_event_count, __ATOMIC_SEQ_CST) >= 4;
}


static void check_dtmf(int i, char digit, bool end, bool via_sip_info)
{
	printf("victim dtmf: event %d digit=%c end=%d via_sip_info=%d\n", i,
	       dtmf_events[i].digit ? dtmf_events[i].digit : '-',
	       dtmf_events[i].end, dtmf_events[i].via_sip_info);
	CHECK(dtmf_events[i].end == end);
	CHECK(end || dtmf_events[i].digit == digit);
	CHECK(dtmf_events[i].via_sip_info == via_sip_info);
}


static int run_dtmf(const char *host)
{
	(void)start(host, false);
	CHECK(wait_until(&w, has_connected, 15000));
	CHECK(wait_until(&w, four_dtmf_events, 10000));
	check_dtmf(0, '5', false, true);
	check_dtmf(1, 0, true, true);
	check_dtmf(2, '7', false, false);
	check_dtmf(3, 0, true, false);
	CHECK(wait_until(&w, one_released, 10000));
	CHECK(__atomic_load_n(&dtmf_event_count, __ATOMIC_SEQ_CST) == 4);
	finish("SIP INFO digits are marked, RTP events are not");
	return 0;
}


int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: %s MODE HOST\n", argv[0]);
		return 2;
	}

	mode = argv[1];
	if (mode_is("refer-ringing"))
		return run_refer_ringing(argv[2]);
	if (mode_is("fake-replace"))
		return run_fake_replace(argv[2]);
	if (mode_is("reentrant"))
		return run_reentrant(argv[2]);
	if (mode_is("remove-live"))
		return run_remove_live(argv[2], false);
	if (mode_is("stop-live"))
		return run_remove_live(argv[2], true);
	if (mode_is("dtmf"))
		return run_dtmf(argv[2]);

	fprintf(stderr, "unknown mode %s\n", mode);
	return 2;
}
