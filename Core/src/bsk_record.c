#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "bsk_internal.h"

struct bsk_rec {
	struct le le;
	const struct audio *au;
	mtx_t mtx;
	FILE *f;
	uint32_t srate;
	uint64_t frames;
	int16_t *side[2];
	size_t n[2];
	size_t cap;
};

struct rec_enc {
	struct aufilt_enc_st af;
	struct bsk_rec *r;
};

struct rec_dec {
	struct aufilt_dec_st af;
	struct bsk_rec *r;
};

static struct list recl;
static mtx_t recl_mtx;
static bool recl_ready;


static void put_le32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)v;
	p[1] = (uint8_t)(v >> 8);
	p[2] = (uint8_t)(v >> 16);
	p[3] = (uint8_t)(v >> 24);
}


static void put_le16(uint8_t *p, uint16_t v)
{
	p[0] = (uint8_t)v;
	p[1] = (uint8_t)(v >> 8);
}


static void write_header(FILE *f, uint32_t srate, uint64_t frames)
{
	uint8_t h[44];
	uint64_t bytes = frames * 4;
	uint32_t data = bytes > 0xffffffd3ULL ? 0xffffffd3U : (uint32_t)bytes;

	memcpy(h, "RIFF", 4);
	put_le32(h + 4, 36 + data);
	memcpy(h + 8, "WAVEfmt ", 8);
	put_le32(h + 16, 16);
	put_le16(h + 20, 1);
	put_le16(h + 22, 2);
	put_le32(h + 24, srate);
	put_le32(h + 28, srate * 4);
	put_le16(h + 32, 4);
	put_le16(h + 34, 16);
	memcpy(h + 36, "data", 4);
	put_le32(h + 40, data);

	(void)fseek(f, 0, SEEK_SET);
	(void)fwrite(h, 1, sizeof(h), f);
	(void)fseek(f, 0, SEEK_END);
}


static void write_frames(struct bsk_rec *r, size_t count)
{
	int16_t buf[2 * 480];
	size_t done = 0;
	size_t i;

	while (done < count) {
		size_t chunk = count - done;

		if (chunk > 480)
			chunk = 480;

		for (i = 0; i < chunk; i++) {
			size_t k = done + i;

			buf[2 * i]     = k < r->n[0] ? r->side[0][k] : 0;
			buf[2 * i + 1] = k < r->n[1] ? r->side[1][k] : 0;
		}

		(void)fwrite(buf, sizeof(int16_t), 2 * chunk, r->f);
		done += chunk;
	}

	r->frames += count;

	for (i = 0; i < 2; i++) {
		size_t used = count < r->n[i] ? count : r->n[i];

		memmove(r->side[i], r->side[i] + used,
			(r->n[i] - used) * sizeof(int16_t));
		r->n[i] -= used;
	}
}


static void finish_file(struct bsk_rec *r)
{
	size_t rest;

	if (!r->f)
		return;

	rest = r->n[0] > r->n[1] ? r->n[0] : r->n[1];
	if (rest)
		write_frames(r, rest);

	write_header(r->f, r->srate ? r->srate : 8000, r->frames);
	(void)fclose(r->f);
	r->f = NULL;
}


static void rec_destructor(void *arg)
{
	struct bsk_rec *r = arg;

	mtx_lock(&recl_mtx);
	list_unlink(&r->le);
	mtx_unlock(&recl_mtx);

	mtx_lock(&r->mtx);
	finish_file(r);
	mtx_unlock(&r->mtx);

	mem_deref(r->side[0]);
	mem_deref(r->side[1]);
	mtx_destroy(&r->mtx);
}


static struct bsk_rec *rec_find(const struct audio *au)
{
	struct le *le;

	for (le = recl.head; le; le = le->next) {
		struct bsk_rec *r = le->data;

		if (r->au == au)
			return r;
	}

	return NULL;
}


static struct bsk_rec *rec_get(const struct audio *au)
{
	struct bsk_rec *r;

	mtx_lock(&recl_mtx);
	r = rec_find(au);
	if (r) {
		mem_ref(r);
	}
	else {
		r = mem_zalloc(sizeof(*r), rec_destructor);
		if (r) {
			r->au = au;
			mtx_init(&r->mtx, mtx_plain);
			list_append(&recl, &r->le, r);
		}
	}
	mtx_unlock(&recl_mtx);

	return r;
}


static void rec_push(struct bsk_rec *r, const struct auframe *af, int side)
{
	const int16_t *s = af->sampv;
	size_t frames, i;

	if (!r || !af || !af->sampv || af->fmt != AUFMT_S16LE || !af->ch)
		return;

	mtx_lock(&r->mtx);

	if (!r->f)
		goto out;

	if (!r->srate)
		r->srate = af->srate;
	if (af->srate != r->srate)
		goto out;

	frames = af->sampc / af->ch;

	if (!r->cap) {
		r->cap = r->srate;
		r->side[0] = mem_zalloc(r->cap * sizeof(int16_t), NULL);
		r->side[1] = mem_zalloc(r->cap * sizeof(int16_t), NULL);
		if (!r->side[0] || !r->side[1]) {
			finish_file(r);
			goto out;
		}
	}

	if (r->n[side] + frames > r->cap)
		write_frames(r, r->n[side]);

	for (i = 0; i < frames && r->n[side] < r->cap; i++)
		r->side[side][r->n[side]++] = s[i * af->ch];

	if (r->n[0] && r->n[1])
		write_frames(r, r->n[0] < r->n[1] ? r->n[0] : r->n[1]);
	else if (r->n[side] > r->srate / 5)
		write_frames(r, r->n[side]);

 out:
	mtx_unlock(&r->mtx);
}


static void enc_destructor(void *arg)
{
	struct rec_enc *st = arg;

	list_unlink(&st->af.le);
	mem_deref(st->r);
}


static void dec_destructor(void *arg)
{
	struct rec_dec *st = arg;

	list_unlink(&st->af.le);
	mem_deref(st->r);
}


static int enc_update(struct aufilt_enc_st **stp, void **ctx,
		      const struct aufilt *af, struct aufilt_prm *prm,
		      const struct audio *au)
{
	struct rec_enc *st;
	(void)ctx;
	(void)af;
	(void)prm;

	if (!stp || !au)
		return EINVAL;
	if (*stp)
		return 0;

	st = mem_zalloc(sizeof(*st), enc_destructor);
	if (!st)
		return ENOMEM;

	st->r = rec_get(au);
	if (!st->r) {
		mem_deref(st);
		return ENOMEM;
	}

	*stp = (struct aufilt_enc_st *)st;
	return 0;
}


static int dec_update(struct aufilt_dec_st **stp, void **ctx,
		      const struct aufilt *af, struct aufilt_prm *prm,
		      const struct audio *au)
{
	struct rec_dec *st;
	(void)ctx;
	(void)af;
	(void)prm;

	if (!stp || !au)
		return EINVAL;
	if (*stp)
		return 0;

	st = mem_zalloc(sizeof(*st), dec_destructor);
	if (!st)
		return ENOMEM;

	st->r = rec_get(au);
	if (!st->r) {
		mem_deref(st);
		return ENOMEM;
	}

	*stp = (struct aufilt_dec_st *)st;
	return 0;
}


static int encode(struct aufilt_enc_st *st, struct auframe *af)
{
	rec_push(((struct rec_enc *)st)->r, af, 0);
	return 0;
}


static int decode(struct aufilt_dec_st *st, struct auframe *af)
{
	rec_push(((struct rec_dec *)st)->r, af, 1);
	return 0;
}


static struct aufilt rec_filter = {
	.name    = "bskrec",
	.enabled = true,
	.encupdh = enc_update,
	.ench    = encode,
	.decupdh = dec_update,
	.dech    = decode,
};


int bsk_record_init(void)
{
	if (!recl_ready) {
		mtx_init(&recl_mtx, mtx_plain);
		list_init(&recl);
		recl_ready = true;
	}

	aufilt_register(baresip_aufiltl(), &rec_filter);
	return 0;
}


void bsk_record_close(void)
{
	aufilt_unregister(&rec_filter);
}


int bsk_record_start(const struct audio *au, const char *path, void **handle)
{
	struct bsk_rec *r;
	uint8_t blank[44];
	int err = 0;

	if (!au || !str_isset(path) || !handle)
		return EINVAL;
	if (*handle)
		return EALREADY;

	r = rec_get(au);
	if (!r)
		return ENOMEM;

	mtx_lock(&r->mtx);
	if (r->f) {
		err = EALREADY;
		goto out;
	}

	r->f = fopen(path, "wb");
	if (!r->f) {
		err = errno ? errno : EIO;
		goto out;
	}

	memset(blank, 0, sizeof(blank));
	(void)fwrite(blank, 1, sizeof(blank), r->f);
	r->frames = 0;
	r->n[0] = r->n[1] = 0;

 out:
	mtx_unlock(&r->mtx);
	if (err)
		mem_deref(r);
	else
		*handle = r;
	return err;
}


int bsk_record_stop(void **handle)
{
	struct bsk_rec *r;

	if (!handle || !*handle)
		return EALREADY;

	r = *handle;
	*handle = NULL;

	mtx_lock(&r->mtx);
	finish_file(r);
	mtx_unlock(&r->mtx);
	mem_deref(r);

	return 0;
}
