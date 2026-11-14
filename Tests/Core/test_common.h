#ifndef BSK_TEST_COMMON_H
#define BSK_TEST_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include "baresip_kit.h"

#define CHECK(cond)                                                          \
	do {                                                                 \
		if (!(cond)) {                                               \
			fprintf(stderr, "CHECK failed: %s (%s:%d)\n", #cond, \
				__FILE__, __LINE__);                         \
			exit(1);                                             \
		}                                                            \
	} while (0)

#define CHECK_OK(st, err)                                                      \
	do {                                                                   \
		bsk_status _s = (st);                                          \
		if (_s != BSK_OK) {                                            \
			fprintf(stderr,                                        \
				"CHECK_OK failed: %s -> %s (%d) %s (%s:%d)\n", \
				#st, bsk_status_string(_s), (err)->sys_errno,  \
				(err)->message, __FILE__, __LINE__);           \
			exit(1);                                               \
		}                                                              \
	} while (0)

static const char *test_modules[] = { "g711",     "l16",       "auconv",
				      "auresamp", "ausine",    "aufile",
				      "ice",      "turn",      "stun",
				      "srtp",     "dtls_srtp", "rtcpsummary" };

static void test_log(bsk_log_level level, bsk_log_domain domain,
		     const char *line, size_t len, void *user)
{
	const char *tag = user ? (const char *)user : "";
	(void)len;
	if (getenv("BSK_TEST_VERBOSE"))
		fprintf(stderr, "%s[%d/%d] %s\n", tag, level, domain, line);
}

struct waiter {
	pthread_mutex_t mtx;
	pthread_cond_t cnd;
	int reg_state;
	int reg_count;
	int call_state;
	int call_state_count;
	int media_event;
	int dtmf_count;
	char dtmf[32];
	int engine_state;
	bsk_call_id incoming_call;
	bsk_call_id released_call;
	int stats_count;
	int ice_state;
	int ice_local_type;
	int ice_remote_type;
	bsk_error last_error;
};

static void waiter_init(struct waiter *w)
{
	memset(w, 0, sizeof(*w));
	pthread_mutex_init(&w->mtx, NULL);
	pthread_cond_init(&w->cnd, NULL);
	w->reg_state = -1;
	w->call_state = -1;
	w->media_event = -1;
	w->engine_state = -1;
	w->ice_state = -1;
}

static void waiter_signal(struct waiter *w)
{
	pthread_cond_broadcast(&w->cnd);
}

static bool wait_until(struct waiter *w, int (*pred)(struct waiter *),
		       int timeout_ms)
{
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	ts.tv_sec += timeout_ms / 1000;
	ts.tv_nsec += (timeout_ms % 1000) * 1000000L;
	if (ts.tv_nsec >= 1000000000L) {
		ts.tv_sec++;
		ts.tv_nsec -= 1000000000L;
	}
	pthread_mutex_lock(&w->mtx);
	while (!pred(w)) {
		if (pthread_cond_timedwait(&w->cnd, &w->mtx, &ts) != 0) {
			pthread_mutex_unlock(&w->mtx);
			return false;
		}
	}
	pthread_mutex_unlock(&w->mtx);
	return true;
}

static int waiter_int(struct waiter *w, const int *field)
{
	int value;

	pthread_mutex_lock(&w->mtx);
	value = *field;
	pthread_mutex_unlock(&w->mtx);
	return value;
}

static void record_event(struct waiter *w, const bsk_event *ev)
{
	pthread_mutex_lock(&w->mtx);
	switch (ev->type) {
	case BSK_EVENT_ENGINE_STATE:
		w->engine_state = ev->u.engine.state;
		break;
	case BSK_EVENT_REGISTRATION:
		w->reg_state = ev->u.registration.state;
		if (ev->u.registration.state == BSK_REG_REGISTERED)
			w->reg_count++;
		w->last_error = ev->u.registration.error;
		break;
	case BSK_EVENT_CALL_INCOMING: w->incoming_call = ev->call; break;
	case BSK_EVENT_CALL_STATE:
		w->call_state = ev->u.call_state.state;
		w->call_state_count++;
		if (ev->u.call_state.state == BSK_CALL_RELEASED)
			w->released_call = ev->call;
		w->last_error = ev->u.call_state.error;
		break;
	case BSK_EVENT_CALL_MEDIA: w->media_event = ev->u.media.event; break;
	case BSK_EVENT_CALL_DTMF:
		if (!ev->u.dtmf.end && w->dtmf_count < 31)
			w->dtmf[w->dtmf_count++] = ev->u.dtmf.digit;
		break;
	case BSK_EVENT_CALL_STATISTICS: w->stats_count++; break;
	case BSK_EVENT_ICE:
		w->ice_state = ev->u.ice.state;
		w->ice_local_type = ev->u.ice.local_candidate;
		w->ice_remote_type = ev->u.ice.remote_candidate;
		break;
	default: break;
	}
	waiter_signal(w);
	pthread_mutex_unlock(&w->mtx);
}


static __attribute__((unused)) int running(struct waiter *x)
{
	return x->engine_state == BSK_ENGINE_RUNNING;
}

static __attribute__((unused)) int registered(struct waiter *x)
{
	return x->reg_state == BSK_REG_REGISTERED;
}

static __attribute__((unused)) int incoming(struct waiter *x)
{
	return x->incoming_call != BSK_ID_NONE;
}

static __attribute__((unused)) int streams(struct waiter *x)
{
	return x->call_state == BSK_CALL_STREAMS_RUNNING;
}

static __attribute__((unused)) int paused(struct waiter *x)
{
	return x->call_state == BSK_CALL_PAUSED;
}

static __attribute__((unused)) int released(struct waiter *x)
{
	return x->released_call != BSK_ID_NONE;
}

static __attribute__((unused)) int ice_connected(struct waiter *x)
{
	return x->ice_state == BSK_ICE_CONNECTED;
}

static __attribute__((unused)) char *read_file(const char *path, size_t *len)
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

/* Writes a WAV file with a 440 Hz tone: PCM with the given sample size, or a
 * file that is not a WAV when bits is 0. */
static __attribute__((unused)) void write_test_wav(const char *path,
						   unsigned srate, unsigned ch,
						   unsigned bits, unsigned ms)
{
	FILE *f = fopen(path, "wb");
	unsigned frames = srate * ms / 1000, bytes = bits / 8;
	unsigned data = frames * ch * bytes, i, c;
	unsigned char h[44];

	CHECK(f != NULL);
	if (!bits) {
		fputs("not a wave file, just some text to fill the header", f);
		fclose(f);
		return;
	}
	memcpy(h, "RIFF", 4);
	h[4] = (unsigned char)(36 + data);
	h[5] = (unsigned char)((36 + data) >> 8);
	h[6] = (unsigned char)((36 + data) >> 16);
	h[7] = (unsigned char)((36 + data) >> 24);
	memcpy(h + 8, "WAVEfmt ", 8);
	memset(h + 16, 0, 28);
	h[16] = 16;
	h[20] = 1;
	h[22] = (unsigned char)ch;
	h[24] = (unsigned char)srate;
	h[25] = (unsigned char)(srate >> 8);
	h[26] = (unsigned char)(srate >> 16);
	h[28] = (unsigned char)(srate * ch * bytes);
	h[29] = (unsigned char)((srate * ch * bytes) >> 8);
	h[30] = (unsigned char)((srate * ch * bytes) >> 16);
	h[32] = (unsigned char)(ch * bytes);
	h[34] = (unsigned char)bits;
	memcpy(h + 36, "data", 4);
	h[40] = (unsigned char)data;
	h[41] = (unsigned char)(data >> 8);
	h[42] = (unsigned char)(data >> 16);
	h[43] = (unsigned char)(data >> 24);
	CHECK(fwrite(h, 1, sizeof(h), f) == sizeof(h));
	for (i = 0; i < frames; i++) {
		int v = (int)(8000.0 *
			      ((i * 440 / (srate / 4)) % 4 < 2 ? 1 : -1));

		for (c = 0; c < ch; c++) {
			if (bytes == 2) {
				fputc(v & 0xff, f);
				fputc((v >> 8) & 0xff, f);
			} else {
				fputc(128 + v / 256, f);
			}
		}
	}
	fclose(f);
}

#endif
