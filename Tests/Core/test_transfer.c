#include <unistd.h>
#include "test_common.h"

static struct waiter w;
static const char *tag;
static int streams_n;
static int released_n;
static int message_n;
static int delivered_n;
static char last_message[256];
static char last_from[256];

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	pthread_mutex_lock(&w.mtx);
	if (ev->type == BSK_EVENT_CALL_STATE) {
		fprintf(stderr, "%s: call %llu state %d\n", tag,
			(unsigned long long)ev->call, ev->u.call_state.state);
		if (ev->u.call_state.state == BSK_CALL_STREAMS_RUNNING)
			streams_n++;
		if (ev->u.call_state.state == BSK_CALL_RELEASED)
			released_n++;
	} else if (ev->type == BSK_EVENT_MESSAGE) {
		size_t n = ev->u.message.body_len < sizeof(last_message) - 1
				   ? ev->u.message.body_len
				   : sizeof(last_message) - 1;
		memcpy(last_message, ev->u.message.body, n);
		last_message[n] = '\0';
		snprintf(last_from, sizeof(last_from), "%s",
			 ev->u.message.from);
		message_n++;
	} else if (ev->type == BSK_EVENT_MESSAGE_STATUS) {
		if (ev->u.message_status.delivered &&
		    ev->u.message_status.sip_status == 200)
			delivered_n++;
	}
	pthread_mutex_unlock(&w.mtx);
	record_event(&w, ev);
}

static int running(struct waiter *x)
{
	return x->engine_state == BSK_ENGINE_RUNNING;
}
static int incoming(struct waiter *x)
{
	return x->incoming_call != BSK_ID_NONE;
}
static int streams1(struct waiter *x)
{
	(void)x;
	return streams_n >= 1;
}
static int streams2(struct waiter *x)
{
	(void)x;
	return streams_n >= 2;
}
static int released1(struct waiter *x)
{
	(void)x;
	return released_n >= 1;
}
static int released2(struct waiter *x)
{
	(void)x;
	return released_n >= 2;
}
static int got_message(struct waiter *x)
{
	(void)x;
	return message_n >= 1;
}
static int delivered(struct waiter *x)
{
	(void)x;
	return delivered_n >= 1;
}


static bsk_engine *start_engine(const char *port, uint16_t rtp)
{
	static char extra[128];
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;

	snprintf(extra, sizeof(extra), "sip_listen\t\t0.0.0.0:%s", port);

	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = test_modules;
	cfg.module_count = sizeof(test_modules) / sizeof(test_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.log_level =
		getenv("BSK_TEST_VERBOSE") ? BSK_LOG_DEBUG : BSK_LOG_INFO;
	cfg.log_sip_trace = getenv("BSK_TEST_VERBOSE") != NULL;
	cfg.extra_config = extra;
	cfg.rtp_port_min = rtp;
	cfg.rtp_port_max = rtp + 100;

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
	ac.audio_codecs = codecs;
	ac.audio_codec_count = 1;
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	return acc;
}


static void remote_of(bsk_engine *e, bsk_call_id call, char *out, size_t len)
{
	bsk_call_info info;

	CHECK(BSK_OK == bsk_call_get_info(e, call, &info));
	snprintf(out, len, "%s", info.remote_uri);
}


static bsk_call_id running_call_with(bsk_engine *e, const char *peer,
				     int timeout_ms)
{
	int waited;

	for (waited = 0; waited < timeout_ms; waited += 100) {
		bsk_call_id ids[4];
		size_t n = bsk_call_list(e, ids, 4), i;

		for (i = 0; i < n && i < 4; i++) {
			bsk_call_info info;

			if (BSK_OK != bsk_call_get_info(e, ids[i], &info))
				continue;
			if (strstr(info.remote_uri, peer) &&
			    info.state == BSK_CALL_STREAMS_RUNNING)
				return ids[i];
		}
		usleep(100000);
	}

	return BSK_ID_NONE;
}


static int run_b(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	char remote[256];
	bsk_call_id call;

	tag = "B";
	e = start_engine("5370", 30400);
	add_account(e, "bob", host, "5370");
	printf("READY\n");
	fflush(stdout);

	CHECK(wait_until(&w, got_message, 15000));
	CHECK(0 == strcmp(last_message, "hello bob"));
	CHECK(strstr(last_from, "alice") != NULL);

	CHECK(wait_until(&w, incoming, 15000));
	CHECK_OK(bsk_call_answer(e, w.incoming_call, false, &err), &err);

	CHECK(wait_until(&w, released1, 30000));
	call = running_call_with(e, "carol", 15000);
	CHECK(call != BSK_ID_NONE);
	CHECK(bsk_call_list(e, NULL, 0) == 1);
	remote_of(e, call, remote, sizeof(remote));
	sleep(2);
	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released2, 10000));

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("B: PASS (message from alice, transferred to %s)\n", remote);
	return 0;
}


static int run_c(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	char remote[256];
	bsk_call_id call;

	tag = "C";
	e = start_engine("5380", 30600);
	add_account(e, "carol", host, "5380");
	printf("READY\n");
	fflush(stdout);

	CHECK(wait_until(&w, incoming, 20000));
	remote_of(e, w.incoming_call, remote, sizeof(remote));
	CHECK(strstr(remote, "alice") != NULL);
	CHECK_OK(bsk_call_answer(e, w.incoming_call, false, &err), &err);
	CHECK(wait_until(&w, streams1, 10000));

	call = running_call_with(e, "bob", 20000);
	CHECK(call != BSK_ID_NONE);
	remote_of(e, call, remote, sizeof(remote));
	CHECK(wait_until(&w, released2, 20000));

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("C: PASS (replaced call from alice by call from %s)\n", remote);
	return 0;
}


static int run_a(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_account_id acc;
	bsk_call_id to_b = BSK_ID_NONE, to_c = BSK_ID_NONE;
	uint64_t msg_id = 0;
	char dest[128];

	tag = "A";
	e = start_engine("5360", 30200);
	acc = add_account(e, "alice", host, "5360");

	snprintf(dest, sizeof(dest), "sip:bob@%s:5370", host);
	CHECK_OK(bsk_message_send(e, acc, dest, "hello bob", &msg_id, &err),
		 &err);
	CHECK(msg_id != 0);
	CHECK(wait_until(&w, delivered, 10000));

	CHECK_OK(bsk_call_make(e, acc, dest, false, &to_b, &err), &err);
	CHECK(wait_until(&w, streams1, 15000));
	CHECK_OK(bsk_call_hold(e, to_b, true, &err), &err);
	sleep(1);

	snprintf(dest, sizeof(dest), "sip:carol@%s:5380", host);
	CHECK_OK(bsk_call_make(e, acc, dest, false, &to_c, &err), &err);
	CHECK(wait_until(&w, streams2, 15000));
	sleep(1);

	CHECK(BSK_ERR_INVALID_ARGUMENT ==
	      bsk_call_transfer_attended(e, to_b, to_b, &err));
	CHECK_OK(bsk_call_transfer_attended(e, to_b, to_c, &err), &err);
	CHECK(wait_until(&w, released2, 20000));
	CHECK(bsk_call_list(e, NULL, 0) == 0);

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("A: PASS (message delivered, attended transfer of bob to carol)\n");
	return 0;
}


int main(int argc, char **argv)
{
	const char *role = argc > 1 ? argv[1] : "a";
	const char *host = argc > 2 ? argv[2] : "127.0.0.1";

	waiter_init(&w);
	if (0 == strcmp(role, "b"))
		return run_b(host);
	if (0 == strcmp(role, "c"))
		return run_c(host);
	return run_a(host);
}
