#include "bsk_rate.h"

enum {
	RATE_MIN_PACKETS = 20,
	RATE_INCREASE_INTERVAL_MS = 2000,
	RATE_INCREASE_STEP_BPS = 8000
};


static uint32_t clamp(const struct bsk_rate *r, uint64_t v)
{
	if (v < r->min)
		return r->min;
	if (v > r->max)
		return r->max;
	return (uint32_t)v;
}


void bsk_rate_init(struct bsk_rate *r, uint32_t start, uint32_t min,
		   uint32_t max, uint64_t now_ms)
{
	if (!r)
		return;

	r->max = max;
	r->min = min < max ? min : max;
	r->current = clamp(r, start ? start : max);
	r->last_sent = 0;
	r->last_lost = 0;
	r->last_change_ms = now_ms;
	r->primed = false;
}


void bsk_rate_set_max(struct bsk_rate *r, uint32_t max)
{
	if (!r || !max)
		return;

	r->max = max;
	if (r->min > max)
		r->min = max;
	r->current = clamp(r, r->current);
}


uint32_t bsk_rate_update(struct bsk_rate *r, uint32_t sent, int32_t lost,
			 uint64_t now_ms)
{
	uint32_t dsent;
	int64_t dlost;
	uint64_t next;

	if (!r)
		return 0;

	if (!r->primed || sent < r->last_sent) {
		r->last_sent = sent;
		r->last_lost = lost;
		r->primed = true;
		return r->current;
	}

	dsent = sent - r->last_sent;
	if (dsent < RATE_MIN_PACKETS)
		return r->current;

	dlost = (int64_t)lost - r->last_lost;
	if (dlost < 0)
		dlost = 0;
	if (dlost > dsent)
		dlost = dsent;

	r->last_sent = sent;
	r->last_lost = lost;

	next = r->current;

	if ((uint64_t)dlost * 10 > dsent) {
		next = r->current -
		       (uint64_t)r->current * (uint64_t)dlost / (2u * dsent);
		r->last_change_ms = now_ms;
	} else if ((uint64_t)dlost * 50 < dsent &&
		   now_ms - r->last_change_ms >= RATE_INCREASE_INTERVAL_MS) {
		next = (uint64_t)r->current + r->current / 12 +
		       RATE_INCREASE_STEP_BPS;
		r->last_change_ms = now_ms;
	}

	next = clamp(r, next);

	if (next != r->current &&
	    ((next > r->current ? next - r->current : r->current - next) * 20 >=
		     r->current ||
	     next == r->min || next == r->max))
		r->current = (uint32_t)next;

	return r->current;
}
