#ifndef BSK_H264_H
#define BSK_H264_H

#include <re.h>

enum {
	BSK_H264_MAX_UNIT = 1024 * 1024,
	BSK_H264_MAX_PARAM_SET = 256,
};

struct bsk_h264_depack {
	struct mbuf *mb;
	bool frag;
	size_t frag_start;
	uint16_t frag_seq;
	unsigned n_lost;
};

struct bsk_h264_unit {
	const uint8_t *sps;
	size_t sps_len;
	const uint8_t *pps;
	size_t pps_len;
	bool have_slice;
	bool keyframe;
};

int bsk_h264_depack_init(struct bsk_h264_depack *d);
void bsk_h264_depack_close(struct bsk_h264_depack *d);
void bsk_h264_depack_reset(struct bsk_h264_depack *d);
int bsk_h264_depack_put(struct bsk_h264_depack *d, struct mbuf *src,
			uint16_t seq, bool marker, bool *complete);
int bsk_h264_annexb_to_avcc(const uint8_t *buf, size_t len, struct mbuf *avcc,
			    struct bsk_h264_unit *unit);

#endif
