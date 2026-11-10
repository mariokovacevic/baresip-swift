#include <errno.h>
#include <string.h>
#include "bsk_internal.h"

#define BSK_AUDIO_MODULE "bskaudio"

struct ausrc_st {
	struct ausrc_st *inner;
};

struct auplay_st {
	struct auplay_st *inner;
};

static struct ausrc *bsk_ausrc;
static struct auplay *bsk_auplay;


static void src_destructor(void *arg)
{
	struct ausrc_st *st = arg;

	mem_deref(st->inner);
}


static void play_destructor(void *arg)
{
	struct auplay_st *st = arg;

	mem_deref(st->inner);
}


static bool audio_live(const bsk_engine *e)
{
	return e && e->audio_active;
}


static int src_alloc(struct ausrc_st **stp, const struct ausrc *as,
		     struct ausrc_prm *prm, const char *device,
		     ausrc_read_h *rh, ausrc_error_h *errh, void *arg)
{
	bsk_engine *e = bsk_global_engine();
	struct ausrc_st *st;
	int err = 0;
	(void)as;
	(void)device;

	if (!stp || !prm)
		return EINVAL;

	st = mem_zalloc(sizeof(*st), src_destructor);
	if (!st)
		return ENOMEM;

	if (audio_live(e))
		err = ausrc_alloc(&st->inner, baresip_ausrcl(),
				  e->audio_src_mod, prm, e->audio_src_dev, rh,
				  errh, arg);

	if (err)
		mem_deref(st);
	else
		*stp = st;

	return err;
}


static int play_alloc(struct auplay_st **stp, const struct auplay *ap,
		      struct auplay_prm *prm, const char *device,
		      auplay_write_h *wh, void *arg)
{
	bsk_engine *e = bsk_global_engine();
	struct auplay_st *st;
	int err = 0;
	(void)ap;
	(void)device;

	if (!stp || !prm)
		return EINVAL;

	st = mem_zalloc(sizeof(*st), play_destructor);
	if (!st)
		return ENOMEM;

	if (audio_live(e))
		err = auplay_alloc(&st->inner, baresip_auplayl(),
				   e->audio_play_mod, prm, e->audio_play_dev,
				   wh, arg);

	if (err)
		mem_deref(st);
	else
		*stp = st;

	return err;
}


int bsk_audio_init(void)
{
	struct config_audio *cfg = &conf_config()->audio;
	int err;

	err = ausrc_register(&bsk_ausrc, baresip_ausrcl(), BSK_AUDIO_MODULE,
			     src_alloc);
	if (err)
		return err;

	err = auplay_register(&bsk_auplay, baresip_auplayl(), BSK_AUDIO_MODULE,
			      play_alloc);
	if (err)
		return err;

	str_ncpy(cfg->src_mod, BSK_AUDIO_MODULE, sizeof(cfg->src_mod));
	cfg->src_dev[0] = '\0';
	str_ncpy(cfg->play_mod, BSK_AUDIO_MODULE, sizeof(cfg->play_mod));
	cfg->play_dev[0] = '\0';

	return 0;
}


void bsk_audio_close(void)
{
	bsk_ausrc = mem_deref(bsk_ausrc);
	bsk_auplay = mem_deref(bsk_auplay);
}
