#ifndef BSK_RATE_H
#define BSK_RATE_H

#include <stdbool.h>
#include <stdint.h>

struct bsk_rate {
	uint32_t current;
	uint32_t min;
	uint32_t max;
	uint32_t last_sent;
	int32_t last_lost;
	uint64_t last_change_ms;
	bool primed;
};

void bsk_rate_init(struct bsk_rate *r, uint32_t start, uint32_t min,
		   uint32_t max, uint64_t now_ms);
void bsk_rate_set_max(struct bsk_rate *r, uint32_t max);
uint32_t bsk_rate_update(struct bsk_rate *r, uint32_t sent, int32_t lost,
			 uint64_t now_ms);
uint32_t bsk_loss_permille(uint32_t received, int32_t lost);
float bsk_mos_estimate(uint32_t loss_permille, uint32_t rtt_ms,
		       uint32_t jitter_buffer_ms);

#endif
