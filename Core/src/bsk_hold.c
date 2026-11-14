#include <errno.h>
#include <string.h>
#include <re_atomic.h>
#include "bsk_internal.h"

#define HOLD_MAX_BYTES (64u * 1024u * 1024u)
#define HOLD_READ_SAMPLES 2048u

struct ausrc_st {
	int16_t *pcm;
	size_t samples;
	size_t pos;
	double fpos;
	double step;
	struct auresamp rs;
	bool fir;
	size_t inframes;
	int16_t *in;
	int16_t *out;
	size_t outcap;
	struct ausrc_prm prm;
	size_t sampc;
	RE_ATOMIC bool run;
	thrd_t thread;
	ausrc_read_h *rh;
	void *arg;
};

static struct ausrc *hold_ausrc;


static int open_error(int err)
{
	switch (err) {
	case ENOENT:
	case ENOMEM:
	case ENOSYS: return err;
	default: return EINVAL;
	}
}


static void downmix(int16_t *pcm, size_t *n, size_t frames, const int16_t *buf,
		    size_t got, uint8_t ch)
{
	size_t i;

	for (i = 0; i < got && *n < frames; i++, (*n)++) {
		int32_t v = buf[i * ch];

		if (ch == 2)
			v = (v + buf[i * ch + 1]) / 2;
		pcm[*n] = (int16_t)v;
	}
}


/* Reads a 16-bit PCM WAV file, mono or stereo, into mono samples. */
int bsk_hold_music_load(bsk_engine *e, const char *path)
{
	struct aufile_prm prm;
	struct aufile *af = NULL;
	int16_t buf[HOLD_READ_SAMPLES];
	int16_t *pcm = NULL;
	size_t bytes, frames, n = 0;
	int err;

	if (!e || !str_isset(path))
		return 0;

	err = aufile_open(&af, &prm, path, AUFILE_READ);
	if (err)
		return open_error(err);

	if (prm.fmt != AUFMT_S16LE || prm.channels < 1 || prm.channels > 2 ||
	    prm.srate < 8000 || prm.srate > 48000) {
		err = ENOSYS;
		goto out;
	}

	bytes = aufile_get_size(af);
	frames = bytes / (2u * prm.channels);
	if (bytes > HOLD_MAX_BYTES || frames < prm.srate / 10) {
		err = EINVAL;
		goto out;
	}

	pcm = mem_alloc(frames * sizeof(*pcm), NULL);
	if (!pcm) {
		err = ENOMEM;
		goto out;
	}

	while (n < frames) {
		size_t sz = sizeof(buf);

		err = aufile_read(af, (uint8_t *)buf, &sz);
		if (err || !sz)
			break;
		downmix(pcm, &n, frames, buf, sz / (2u * prm.channels),
			prm.channels);
	}
	if (err || n < prm.srate / 10) {
		err = EINVAL;
		goto out;
	}

	mem_deref(e->hold_pcm);
	e->hold_pcm = pcm;
	e->hold_samples = n;
	e->hold_srate = prm.srate;
	pcm = NULL;

out:
	mem_deref(pcm);
	mem_deref(af);
	return err;
}


bool bsk_call_hold_music(const bsk_engine *e, const struct bsk_call_ctx *c)
{
	return e && c && e->hold_pcm && c->core_hold;
}


static size_t next_packet(struct ausrc_st *st)
{
	size_t frames = st->sampc / st->prm.ch, i, outc;

	if (!st->fir) {
		for (i = 0; i < frames; i++) {
			size_t i0 = (size_t)st->fpos;
			size_t i1 = i0 + 1 < st->samples ? i0 + 1 : 0;
			double frac = st->fpos - (double)i0;
			int16_t v = (int16_t)(st->pcm[i0] * (1.0 - frac) +
					      st->pcm[i1] * frac);
			uint8_t c;

			for (c = 0; c < st->prm.ch; c++)
				st->out[i * st->prm.ch + c] = v;

			st->fpos += st->step;
			while (st->fpos >= (double)st->samples)
				st->fpos -= (double)st->samples;
		}
		return st->sampc;
	}

	for (i = 0; i < st->inframes; i++) {
		st->in[i] = st->pcm[st->pos];
		if (++st->pos >= st->samples)
			st->pos = 0;
	}

	if (!st->rs.resample) {
		memcpy(st->out, st->in, st->inframes * sizeof(*st->in));
		return st->inframes;
	}

	outc = st->outcap;
	if (auresamp(&st->rs, st->out, &outc, st->in, st->inframes))
		return 0;

	return outc;
}


static void fill(struct ausrc_st *st, void *sampv)
{
	size_t n = MIN(next_packet(st), st->sampc), i;

	for (i = n; i < st->sampc; i++)
		st->out[i] = 0;

	if (st->prm.fmt == AUFMT_FLOAT) {
		for (i = 0; i < st->sampc; i++)
			((float *)sampv)[i] = (float)st->out[i] / 32768.0f;
	} else {
		memcpy(sampv, st->out, st->sampc * sizeof(int16_t));
	}
}


static int play_thread(void *arg)
{
	struct ausrc_st *st = arg;
	uint64_t ts = tmr_jiffies();
	void *sampv;

	sampv = mem_alloc(st->sampc * aufmt_sample_size(st->prm.fmt), NULL);
	if (!sampv)
		return ENOMEM;

	while (re_atomic_rlx(&st->run)) {
		struct auframe af;

		sys_msleep(4);
		if (ts > tmr_jiffies())
			continue;

		fill(st, sampv);
		auframe_init(&af, st->prm.fmt, sampv, st->sampc, st->prm.srate,
			     st->prm.ch);
		af.timestamp = ts * 1000;
		st->rh(&af, st->arg);
		ts += st->prm.ptime;
	}

	mem_deref(sampv);

	return 0;
}


static void src_destructor(void *arg)
{
	struct ausrc_st *st = arg;

	if (re_atomic_rlx(&st->run)) {
		re_atomic_rlx_set(&st->run, false);
		thrd_join(st->thread, NULL);
	}
	mem_deref(st->pcm);
	mem_deref(st->in);
	mem_deref(st->out);
}


static int src_alloc(struct ausrc_st **stp, const struct ausrc *as,
		     struct ausrc_prm *prm, const char *device,
		     ausrc_read_h *rh, ausrc_error_h *errh, void *arg)
{
	bsk_engine *e = bsk_global_engine();
	struct ausrc_st *st;
	int err;
	(void)as;
	(void)device;
	(void)errh;

	if (!stp || !prm || !rh || !prm->srate || !prm->ch || !prm->ptime)
		return EINVAL;
	if (!e || !e->hold_pcm)
		return ENOENT;
	if (prm->fmt != AUFMT_S16LE && prm->fmt != AUFMT_FLOAT)
		return ENOTSUP;

	st = mem_zalloc(sizeof(*st), src_destructor);
	if (!st)
		return ENOMEM;

	st->pcm = mem_ref(e->hold_pcm);
	st->samples = e->hold_samples;
	st->step = (double)e->hold_srate / (double)prm->srate;
	st->prm = *prm;
	st->sampc = (size_t)prm->srate * prm->ch * prm->ptime / 1000;
	st->rh = rh;
	st->arg = arg;

	auresamp_init(&st->rs);
	err = auresamp_setup(&st->rs, e->hold_srate, 1, prm->srate, prm->ch);
	st->fir = !err;
	st->inframes = (size_t)e->hold_srate * prm->ptime / 1000;
	st->outcap = MAX(st->sampc, st->inframes);
	st->out = mem_zalloc(st->outcap * sizeof(*st->out), NULL);
	st->in = mem_zalloc(st->inframes * sizeof(*st->in), NULL);
	if ((err && err != ENOTSUP) || !st->out || !st->in) {
		mem_deref(st);
		return err && err != ENOTSUP ? err : ENOMEM;
	}

	re_atomic_rlx_set(&st->run, true);
	err = thread_create_name(&st->thread, "bskhold", play_thread, st);
	if (err) {
		re_atomic_rlx_set(&st->run, false);
		mem_deref(st);
		return err;
	}

	*stp = st;

	return 0;
}


int bsk_hold_init(void)
{
	return ausrc_register(&hold_ausrc, baresip_ausrcl(), BSK_HOLD_MODULE,
			      src_alloc);
}


void bsk_hold_close(void)
{
	hold_ausrc = mem_deref(hold_ausrc);
}
