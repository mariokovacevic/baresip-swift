#include <errno.h>
#include "bsk_internal.h"
#include "g722_encoder.h"
#include "g722_decoder.h"

enum { G722_BITRATE = 64000, G722_SAMPLES_PER_OCTET = 2 };

struct auenc_state {
	G722_ENC_CTX *enc;
};

struct audec_state {
	G722_DEC_CTX *dec;
};


static void enc_destructor(void *arg)
{
	struct auenc_state *st = arg;

	if (st->enc)
		g722_encoder_destroy(st->enc);
}


static void dec_destructor(void *arg)
{
	struct audec_state *st = arg;

	if (st->dec)
		g722_decoder_destroy(st->dec);
}


static int encode_update(struct auenc_state **aesp, const struct aucodec *ac,
			 struct auenc_param *prm, const char *fmtp)
{
	struct auenc_state *st;
	(void)prm;
	(void)fmtp;

	if (!aesp || !ac)
		return EINVAL;
	if (*aesp)
		return 0;

	st = mem_zalloc(sizeof(*st), enc_destructor);
	if (!st)
		return ENOMEM;

	st->enc = g722_encoder_new(G722_BITRATE, G722_DEFAULT);
	if (!st->enc) {
		mem_deref(st);
		return ENOMEM;
	}

	*aesp = st;
	return 0;
}


static int decode_update(struct audec_state **adsp, const struct aucodec *ac,
			 const char *fmtp)
{
	struct audec_state *st;
	(void)fmtp;

	if (!adsp || !ac)
		return EINVAL;
	if (*adsp)
		return 0;

	st = mem_zalloc(sizeof(*st), dec_destructor);
	if (!st)
		return ENOMEM;

	st->dec = g722_decoder_new(G722_BITRATE, G722_DEFAULT);
	if (!st->dec) {
		mem_deref(st);
		return ENOMEM;
	}

	*adsp = st;
	return 0;
}


static int encode(struct auenc_state *st, bool *marker, uint8_t *buf,
		  size_t *len, int fmt, const void *sampv, size_t sampc)
{
	int n;
	(void)marker;

	if (!st || !buf || !len || !sampv)
		return EINVAL;
	if (fmt != AUFMT_S16LE)
		return ENOTSUP;

	sampc -= sampc % G722_SAMPLES_PER_OCTET;
	if (!sampc) {
		*len = 0;
		return 0;
	}
	if (sampc / G722_SAMPLES_PER_OCTET > *len)
		return EOVERFLOW;

	n = g722_encode(st->enc, sampv, (int)sampc, buf);
	if (n <= 0)
		return EPROTO;

	*len = (size_t)n;
	return 0;
}


static int decode(struct audec_state *st, int fmt, void *sampv, size_t *sampc,
		  bool marker, const uint8_t *buf, size_t len)
{
	int n;
	(void)marker;

	if (!st || !sampv || !sampc || !buf)
		return EINVAL;
	if (fmt != AUFMT_S16LE)
		return ENOTSUP;

	if (len * G722_SAMPLES_PER_OCTET > *sampc)
		return EOVERFLOW;

	n = g722_decode(st->dec, buf, (int)len, sampv);
	if (n < 0)
		return EPROTO;

	*sampc = (size_t)n;
	return 0;
}


static struct aucodec g722 = {
	.pt = "9",
	.name = "G722",
	.srate = 16000,
	.crate = 8000,
	.ch = 1,
	.pch = 1,
	.encupdh = encode_update,
	.ench = encode,
	.decupdh = decode_update,
	.dech = decode,
};


void bsk_g722_init(void)
{
	aucodec_register(baresip_aucodecl(), &g722);
}


void bsk_g722_close(void)
{
	aucodec_unregister(&g722);
}
