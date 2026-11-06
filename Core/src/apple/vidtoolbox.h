#ifndef BSK_VIDTOOLBOX_H
#define BSK_VIDTOOLBOX_H

int vidtoolbox_init(void);
void vidtoolbox_close(void);

int vidtoolbox_encode_update(struct videnc_state **vesp,
			     const struct vidcodec *vc,
			     struct videnc_param *prm, const char *fmtp,
			     videnc_packet_h *pkth, const struct video *vid);
int vidtoolbox_encode(struct videnc_state *st, bool update,
		      const struct vidframe *frame, uint64_t timestamp);
int vidtoolbox_decode_update(struct viddec_state **vdsp,
			     const struct vidcodec *vc, const char *fmtp,
			     const struct video *vid);
int vidtoolbox_decode(struct viddec_state *st, struct vidframe *frame,
		      struct viddec_packet *pkt);
int vidtoolbox_fmtp_enc(struct mbuf *mb, const struct sdp_format *fmt,
			bool offer, void *arg);
bool vidtoolbox_fmtp_cmp(const char *lfmtp, const char *rfmtp, void *arg);
enum {
	BSK_NATIVE_DECODER = 0,
	BSK_NATIVE_CAPTURE = 1,
	BSK_NATIVE_SLOTS = 2
};

void vidtoolbox_native_publish(unsigned slot, void *buffer,
			       const uint8_t *plane);
void *vidtoolbox_native_buffer(const uint8_t *plane);

int bskcapture_init(void);
void bskcapture_close(void);

#endif
