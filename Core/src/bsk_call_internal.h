#ifndef BSK_CALL_INTERNAL_H
#define BSK_CALL_INTERNAL_H

#include "bsk_internal.h"

enum sdp_dir bsk_call_unmap_dir(bsk_media_direction dir);
void bsk_call_fill_info(struct bsk_call_ctx *c, bsk_call_info *info);
void bsk_call_emit_state(bsk_engine *e, struct bsk_call_ctx *c,
			 bsk_call_state state, const bsk_error *error);
void bsk_call_emit_media(bsk_engine *e, struct bsk_call_ctx *c,
			 bsk_media_event me, const char *detail);
void bsk_call_apply_audio_activation(bsk_engine *e, struct bsk_call_ctx *c);
struct ua *bsk_call_owning_ua(bsk_engine *e, struct bsk_call_ctx *c);
enum sdp_dir bsk_call_preview_vdir(const struct bsk_call_ctx *c);
int bsk_call_start_preview(bsk_engine *e, struct bsk_call_ctx *c, bool video);
int bsk_call_ice_restart(struct bsk_call_ctx *c);
void bsk_call_rate_apply(bsk_engine *e, struct bsk_call_ctx *c, bool force);
void bsk_call_fill_stats(struct bsk_call_ctx *c, bsk_call_statistics *st);

#endif
