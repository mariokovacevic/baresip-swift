#ifndef BSK_ENGINE_INTERNAL_H
#define BSK_ENGINE_INTERNAL_H

#include "bsk_internal.h"

int bsk_engine_copy_config(bsk_engine *e, const bsk_engine_config *c);
int bsk_engine_build_config(bsk_engine *e, struct mbuf *mb);
int bsk_engine_apply_tls(bsk_engine *e);

#endif
