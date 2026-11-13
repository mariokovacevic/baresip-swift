#ifndef BSK_REASON_H
#define BSK_REASON_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool bsk_reason_sip_cause(const char *text, uint16_t *cause, char *phrase,
			  size_t size);

#endif
