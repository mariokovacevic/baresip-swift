#include <string.h>
#include "bsk_h264.h"


static const uint8_t nal_seq[3] = { 0, 0, 1 };


int bsk_h264_depack_init(struct bsk_h264_depack *d)
{
	if (!d)
		return EINVAL;

	memset(d, 0, sizeof(*d));
	d->mb = mbuf_alloc(BSK_H264_MAX_UNIT);

	return d->mb ? 0 : ENOMEM;
}


void bsk_h264_depack_close(struct bsk_h264_depack *d)
{
	if (d)
		d->mb = mem_deref(d->mb);
}


void bsk_h264_depack_reset(struct bsk_h264_depack *d)
{
	mbuf_rewind(d->mb);
	d->frag = false;
}


static void drop_fragment(struct bsk_h264_depack *d)
{
	d->mb->pos = d->frag_start;
	d->mb->end = d->frag_start;
	d->frag = false;
	++d->n_lost;
}


static int put_fragment(struct bsk_h264_depack *d, struct mbuf *src,
			struct h264_nal_header *hdr, uint16_t seq, bool *skip)
{
	struct h264_fu fu;
	int err;

	err = h264_fu_hdr_decode(&fu, src);
	if (err) {
		*skip = true;
		return err;
	}
	hdr->type = fu.type;

	if (fu.s) {
		if (d->frag)
			drop_fragment(d);
		d->frag_start = d->mb->pos;
		d->frag = true;
		err = mbuf_write_mem(d->mb, nal_seq, sizeof(nal_seq));
		if (!err)
			err = h264_nal_header_encode(d->mb, hdr);
		if (err)
			return err;
	} else if (!d->frag) {
		++d->n_lost;
		*skip = true;
		return 0;
	} else if (rtp_seq_diff(d->frag_seq, seq) != 1) {
		drop_fragment(d);
		*skip = true;
		return 0;
	}

	err = mbuf_write_mem(d->mb, mbuf_buf(src), mbuf_get_left(src));
	if (err)
		return err;

	if (fu.e)
		d->frag = false;
	d->frag_seq = seq;

	return 0;
}


int bsk_h264_depack_put(struct bsk_h264_depack *d, struct mbuf *src,
			uint16_t seq, bool marker, bool *complete)
{
	struct h264_nal_header hdr;
	bool skip = false;
	int err;

	if (!d || !d->mb || !src || !complete)
		return EINVAL;

	*complete = false;

	err = h264_nal_header_decode(&hdr, src);
	if (err)
		return err;
	if (hdr.f)
		return EBADMSG;

	if (d->frag && hdr.type != H264_NALU_FU_A)
		drop_fragment(d);

	if (1 <= hdr.type && hdr.type <= 23) {
		--src->pos;
		err = mbuf_write_mem(d->mb, nal_seq, sizeof(nal_seq));
		if (!err)
			err = mbuf_write_mem(d->mb, mbuf_buf(src),
					     mbuf_get_left(src));
	} else if (hdr.type == H264_NALU_FU_A) {
		err = put_fragment(d, src, &hdr, seq, &skip);
		if (skip)
			return err;
	} else if (hdr.type == H264_NALU_STAP_A) {
		err = h264_stap_decode_annexb(d->mb, src);
	} else {
		return EBADMSG;
	}
	if (err)
		goto out;

	if (d->mb->end > BSK_H264_MAX_UNIT) {
		err = ENOMEM;
		goto out;
	}
	if (!marker)
		return 0;

	if (d->frag) {
		err = EPROTO;
		goto out;
	}

	*complete = true;
	return 0;

out:
	bsk_h264_depack_reset(d);
	return err;
}


static const uint8_t *skip_startcode(const uint8_t *p, const uint8_t *end)
{
	while (p < end && *p == 0)
		p++;
	if (p < end && *p == 1)
		p++;

	return p;
}


static int put_slice(struct mbuf *avcc, const uint8_t *nal, size_t len)
{
	uint8_t prefix[4] = { (uint8_t)(len >> 24), (uint8_t)(len >> 16),
			      (uint8_t)(len >> 8), (uint8_t)len };
	int err;

	err = mbuf_write_mem(avcc, prefix, sizeof(prefix));
	if (!err)
		err = mbuf_write_mem(avcc, nal, len);

	return err;
}


int bsk_h264_annexb_to_avcc(const uint8_t *buf, size_t len, struct mbuf *avcc,
			    struct bsk_h264_unit *unit)
{
	const uint8_t *end;
	const uint8_t *p;
	int err = 0;

	if (!buf || !avcc || !unit)
		return EINVAL;

	memset(unit, 0, sizeof(*unit));
	if (len < sizeof(nal_seq))
		return 0;

	end = buf + len;
	p = h264_find_startcode(buf, end);

	while (p < end && !err) {
		const uint8_t *nal = skip_startcode(p, end);
		const uint8_t *next = h264_find_startcode(nal, end);
		size_t nal_len = (size_t)(next - nal);
		uint8_t type;

		while (nal_len && nal[nal_len - 1] == 0)
			nal_len--;
		if (!nal_len)
			break;

		type = nal[0] & 0x1f;
		if (type == H264_NALU_SPS &&
		    nal_len <= BSK_H264_MAX_PARAM_SET) {
			unit->sps = nal;
			unit->sps_len = nal_len;
		} else if (type == H264_NALU_PPS &&
			   nal_len <= BSK_H264_MAX_PARAM_SET) {
			unit->pps = nal;
			unit->pps_len = nal_len;
		} else if (type == H264_NALU_IDR_SLICE ||
			   type == H264_NALU_SLICE) {
			err = put_slice(avcc, nal, nal_len);
			unit->have_slice = true;
			unit->keyframe |= type == H264_NALU_IDR_SLICE;
		}

		p = next;
	}

	return err;
}
