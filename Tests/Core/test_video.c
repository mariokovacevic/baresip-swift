#include <unistd.h>
#include "test_common.h"

static struct waiter w;
static const char *tag;
static pthread_mutex_t frame_mtx = PTHREAD_MUTEX_INITIALIZER;
static int remote_frames, local_frames, preview_frames, size_events;
static unsigned last_w, last_h;
static int last_format = -1;

static const char *video_modules[] = {
	"g711", "l16", "auconv", "auresamp", "ausine", "aufile",
	"fakevideo", "vp8", "rtcpsummary"
};

static void on_event(bsk_engine *engine, const bsk_event *ev, void *user)
{
	(void)engine;
	(void)user;
	if (ev->type == BSK_EVENT_CALL_STATE)
		fprintf(stderr, "%s: call %llu state %d\n", tag,
			(unsigned long long)ev->call, ev->u.call_state.state);
	record_event(&w, ev);
}

static void on_frame(bsk_engine *engine, bsk_call_id call, bool local,
		     const bsk_video_frame *frame, void *user)
{
	(void)engine;
	(void)user;
	pthread_mutex_lock(&frame_mtx);
	if (call == BSK_ID_NONE)
		preview_frames++;
	else if (local)
		local_frames++;
	else
		remote_frames++;
	last_w = frame->width;
	last_h = frame->height;
	last_format = frame->format;
	CHECK(frame->planes[0] != NULL);
	CHECK(frame->strides[0] >= frame->width);
	pthread_mutex_unlock(&frame_mtx);
	pthread_mutex_lock(&w.mtx);
	waiter_signal(&w);
	pthread_mutex_unlock(&w.mtx);
}

static void on_size(bsk_engine *engine, bsk_call_id call, bool local,
		    uint32_t width, uint32_t height, void *user)
{
	(void)engine; (void)call; (void)local; (void)width; (void)height; (void)user;
	pthread_mutex_lock(&frame_mtx);
	size_events++;
	pthread_mutex_unlock(&frame_mtx);
}

static int frames(int *counter, int n)
{
	int v;
	pthread_mutex_lock(&frame_mtx);
	v = *counter;
	pthread_mutex_unlock(&frame_mtx);
	return v >= n;
}

static int running(struct waiter *x) { return x->engine_state == BSK_ENGINE_RUNNING; }
static int incoming(struct waiter *x) { return x->incoming_call != BSK_ID_NONE; }
static int connected(struct waiter *x) { return x->call_state >= BSK_CALL_CONNECTED && x->call_state <= BSK_CALL_STREAMS_RUNNING; }
static int released(struct waiter *x) { return x->released_call != BSK_ID_NONE; }
static int remote3(struct waiter *x) { (void)x; return frames(&remote_frames, 3); }
static int local3(struct waiter *x) { (void)x; return frames(&local_frames, 3); }
static int preview3(struct waiter *x) { (void)x; return frames(&preview_frames, 3); }


static bsk_engine *start_engine(const char *listen)
{
	static char extra[128];
	bsk_engine_config cfg;
	bsk_engine *e = NULL;
	bsk_error err;

	snprintf(extra, sizeof(extra), "sip_listen\t\t0.0.0.0:%s", listen);
	memset(&cfg, 0, sizeof(cfg));
	cfg.modules = video_modules;
	cfg.module_count = sizeof(video_modules) / sizeof(video_modules[0]);
	cfg.audio.source_module = "ausine";
	cfg.audio.player_module = "aufile";
	cfg.audio.player_device = "/dev/null";
	cfg.video.source_module = "fakevideo";
	cfg.video.width = getenv("BSK_TEST_VCODEC") ? 640 : 320;
	cfg.video.height = getenv("BSK_TEST_VCODEC") ? 480 : 240;
	cfg.video.fps = 15;
	cfg.video.bitrate_bps = 300000;
	cfg.video_adaptive_bitrate = true;
	cfg.tls.verify_server = true;
	cfg.log_level = getenv("BSK_TEST_VERBOSE") ? BSK_LOG_DEBUG : BSK_LOG_INFO;
	cfg.extra_config = extra;
	cfg.rtp_port_min = 0 == strcmp(listen, "5071") ? 31000 : 41000;
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
	static const char *acodecs[] = { "PCMU/8000/1" };
	static const char *vcodecs[1];

	vcodecs[0] = getenv("BSK_TEST_VCODEC") ? getenv("BSK_TEST_VCODEC") : "VP8";

	snprintf(aor, sizeof(aor), "sip:%s@%s:%s", user, host, port);
	memset(&ac, 0, sizeof(ac));
	ac.aor = aor;
	ac.audio_codecs = acodecs;
	ac.audio_codec_count = 1;
	ac.video_codecs = vcodecs;
	ac.video_codec_count = 1;
	CHECK_OK(bsk_account_add(e, &ac, &acc, &err), &err);
	return acc;
}


static int run_preview(void)
{
	bsk_engine *e;
	bsk_error err;
	bsk_video_sink sink = { on_frame, on_size, NULL };
	char devices[256];

	tag = "preview";
	e = start_engine("0");

	CHECK(BSK_ERR_INVALID_ARGUMENT == bsk_video_preview_start(e, NULL, NULL, &err));
	CHECK_OK(bsk_video_preview_start(e, NULL, &sink, &err), &err);
	CHECK(wait_until(&w, preview3, 3000));
	CHECK(last_w >= 320 && last_h >= 240);
	CHECK(last_format == BSK_PIX_I420);
	CHECK(size_events >= 1);
	CHECK_OK(bsk_video_preview_stop(e, &err), &err);
	{
		int before;
		pthread_mutex_lock(&frame_mtx);
		before = preview_frames;
		pthread_mutex_unlock(&frame_mtx);
		usleep(300000);
		pthread_mutex_lock(&frame_mtx);
		CHECK(preview_frames == before);
		pthread_mutex_unlock(&frame_mtx);
	}
	CHECK_OK(bsk_video_preview_start(e, NULL, &sink, &err), &err);
	(void)bsk_video_list_devices(e, devices, sizeof(devices));

	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("preview: PASS (%d frames %ux%u, devices='%s')\n", preview_frames,
	       last_w, last_h, devices);
	return 0;
}


static int run_callee(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_video_sink sink = { on_frame, on_size, NULL };
	bsk_call_info info;
	bsk_call_statistics st;

	tag = "vcallee";
	e = start_engine("5071");
	add_account(e, "bob", host, "5071");
	printf("READY\n");
	fflush(stdout);

	CHECK(wait_until(&w, incoming, 15000));
	CHECK(BSK_OK == bsk_call_get_info(e, w.incoming_call, &info));
	CHECK(info.has_video);
	CHECK_OK(bsk_call_set_video_sink(e, w.incoming_call, false, &sink, &err), &err);
	CHECK_OK(bsk_call_answer(e, w.incoming_call, true, &err), &err);
	CHECK(wait_until(&w, connected, 10000));
	CHECK(wait_until(&w, remote3, 15000));
	CHECK(BSK_OK == bsk_call_get_statistics(e, w.incoming_call, &st));
	CHECK(st.video.rx_packets > 0);
	CHECK_OK(bsk_call_set_video_sink(e, w.incoming_call, false, NULL, &err), &err);
	CHECK(wait_until(&w, released, 20000));
	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("vcallee: PASS (remote frames=%d %ux%u, video rx=%u pkts)\n",
	       remote_frames, last_w, last_h, st.video.rx_packets);
	return 0;
}


static int run_caller(const char *host)
{
	bsk_engine *e;
	bsk_error err;
	bsk_account_id acc;
	bsk_call_id call = BSK_ID_NONE;
	bsk_video_sink sink = { on_frame, on_size, NULL };
	bsk_call_info info;
	bsk_call_statistics st;
	uint32_t tx_before;
	char dest[128];

	tag = "vcaller";
	e = start_engine("5061");
	acc = add_account(e, "alice", host, "5061");

	snprintf(dest, sizeof(dest), "sip:bob@%s:5071", host);
	CHECK_OK(bsk_call_make(e, acc, dest, true, &call, &err), &err);
	CHECK_OK(bsk_call_set_video_sink(e, call, true, &sink, &err), &err);
	CHECK_OK(bsk_call_set_video_sink(e, call, false, &sink, &err), &err);
	CHECK(wait_until(&w, connected, 15000));
	CHECK(wait_until(&w, local3, 15000));
	CHECK(wait_until(&w, remote3, 15000));
	CHECK(BSK_OK == bsk_call_get_info(e, call, &info));
	CHECK(info.has_video);
	CHECK(0 == strcmp(info.video_codec,
			  getenv("BSK_TEST_VCODEC") ? getenv("BSK_TEST_VCODEC") : "VP8"));
	CHECK_OK(bsk_call_request_keyframe(e, call, &err), &err);
	sleep(1);

	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	CHECK(st.video_target_bitrate_bps >= 150000);
	CHECK(st.video_target_bitrate_bps <= 300000);
	CHECK_OK(bsk_call_set_video_max_bitrate(e, call, 200000, &err), &err);
	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	CHECK(st.video_target_bitrate_bps == 200000);
	tx_before = st.video.tx_packets;
	sleep(2);
	CHECK(BSK_OK == bsk_call_get_statistics(e, call, &st));
	CHECK(st.video_target_bitrate_bps == 200000);
	CHECK(st.video.tx_packets > tx_before);
	CHECK_OK(bsk_call_set_video_max_bitrate(e, call, 0, &err), &err);
	CHECK(BSK_ERR_NOT_FOUND ==
	      bsk_call_set_video_max_bitrate(e, 9999, 100000, &err));

	CHECK_OK(bsk_call_hangup(e, call, &err), &err);
	CHECK(wait_until(&w, released, 10000));
	CHECK_OK(bsk_engine_stop(e, 3000, &err), &err);
	bsk_engine_destroy(e);
	printf("vcaller: PASS (local frames=%d, remote frames=%d, codec=%s,"
	       " capped bitrate 200000)\n",
	       local_frames, remote_frames, info.video_codec);
	return 0;
}


int main(int argc, char **argv)
{
	const char *role = argc > 1 ? argv[1] : "preview";
	const char *host = argc > 2 ? argv[2] : "127.0.0.1";

	waiter_init(&w);
	if (0 == strcmp(role, "callee"))
		return run_callee(host);
	if (0 == strcmp(role, "caller"))
		return run_caller(host);
	return run_preview();
}
