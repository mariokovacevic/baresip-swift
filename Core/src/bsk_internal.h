#ifndef BSK_INTERNAL_H
#define BSK_INTERNAL_H

#include <stdlib.h>
#include <re.h>
#define DEBUG_MODULE "bsk"
#define DEBUG_LEVEL 5
#include <re_dbg.h>
#include <rem.h>
#include <baresip.h>
#include "baresip_kit.h"
#include "bsk_rate.h"

#define BSK_VERSION_STRING "beta"
#ifdef __ANDROID__
#define BSK_DEFAULT_VIDEO_SOURCE "bskcamera"
#else
#define BSK_DEFAULT_VIDEO_SOURCE "bskcapture"
#endif

#define BSK_MAX_MODULES 32
#define BSK_MAX_DTMF 64
#define BSK_DEVICE_MAX 1024
#define BSK_MAX_DTMF_MS 5000
#define BSK_CPARAMS_MAX 1024

typedef int(bsk_op_fn)(bsk_engine *engine, void *arg);

struct bsk_account_ctx {
	struct le le;
	bsk_account_id id;
	struct ua *ua;
	bsk_registration_state state;
	bool reg_inflight;
	bool registered;
	bool has_pending_cparams;
	char pending_cparams[BSK_CPARAMS_MAX];
	bool is_default;
	bool tls;
	bool answer_early_media;
	bool reject_transfers;
	bool removing;
	bool unregistered;
	uint32_t expires;
	uint32_t rtp_timeout_ms;
	uint64_t reg_started_ms;
	struct tmr tmr_remove;
};

struct bsk_call_ctx {
	struct le le;
	bsk_call_id id;
	struct call *call;
	bsk_account_id account;
	bsk_call_state state;
	bsk_call_state steady_state;
	bsk_call_end_reason end_reason;
	bsk_call_id replaces;
	bsk_call_id successor;
	bool outgoing;
	bool video;
	bool local_hold;
	bool core_hold;
	bool hold_queued;
	bool remote_hold;
	bool rtp_established;
	bool early_preview;
	bool preview_video;
	bool preview_audio;
	void *recording;
	bool muted;
	char dtmf_queue[BSK_MAX_DTMF];
	size_t dtmf_pos;
	size_t dtmf_len;
	bool dtmf_tone_on;
	uint32_t dtmf_duration_ms;
	uint32_t dtmf_gap_ms;
	struct tmr tmr_dtmf;
	struct bsk_video_sink remote_sink;
	struct bsk_video_sink local_sink;
	uint64_t created_ms;
	bsk_ice_state ice_state;
	bsk_candidate_type ice_local_type;
	bsk_candidate_type ice_remote_type;
	char ice_local_addr[64];
	char ice_remote_addr[64];
	struct bsk_rate rate;
	bool rate_init;
	uint32_t video_max_bitrate;
	bool closing;
	bool local_hangup;
	bool hangup_pending;
	uint16_t hangup_code;
	char hangup_reason[64];
	struct tmr tmr_hangup;
	struct tmr tmr_modify;
	bool hold_music;
};

struct bsk_engine {
	bsk_event_handler handler;
	void *user;
	bsk_log_handler logh;
	void *log_user;

	char *user_agent;
	char *instance_uuid;
	char *network_interface;
	char *extra_config;
	char *ca_pem;
	size_t ca_pem_len;
	char *client_cert_pem;
	size_t client_cert_pem_len;
	char *cipher_list;
	char *pins[16];
	size_t pin_count;
	bool pin_depth_seen;
	int pin_last_depth;
	int tls_min_version;
	bool verify_server;
	bool ipv6;
	uint16_t rtp_port_min;
	uint16_t rtp_port_max;
	uint32_t max_calls;
	bsk_log_level log_level;
	bool log_sip_trace;
	bool ice_relay_only;
	char *modules[BSK_MAX_MODULES];
	size_t module_count;
	char audio_src_mod[32];
	char audio_src_dev[BSK_DEVICE_MAX];
	char audio_play_mod[32];
	char audio_play_dev[BSK_DEVICE_MAX];
	uint32_t audio_srate;
	uint32_t audio_channels;
	uint32_t audio_ptime;
	uint32_t jb_min_ms;
	uint32_t jb_max_ms;
	bool jb_adaptive;
	char audio_codecs[256];
	char video_codecs[256];
	char video_src_mod[32];
	char video_src_dev[BSK_DEVICE_MAX];
	uint32_t video_width;
	uint32_t video_height;
	uint32_t video_fps;
	uint32_t video_bitrate;

	thrd_t thread;
	bool thread_valid;
	mtx_t mtx;
	cnd_t cnd;
	int start_err;
	bool start_done;
	bool stop_done;
	volatile int state;
	struct mqueue *mq;
	bool mq_open;
	struct list pending_ops;
	mtx_t cb_mtx;
	bool pin_matched;
	struct list accounts;
	struct list calls;
	uint64_t next_account_id;
	uint64_t next_message_id;
	bool replace_pending;
	bool replace_confirmed;
	bool replace_video;
	bsk_call_id replaced_id;
	const struct call *replace_call;
	unsigned emit_depth;
	const struct tls *tls_configured;
	uint64_t next_call_id;
	struct log baresip_log;
	struct tmr tmr_stop;
	struct tmr tmr_running;
	struct tmr tmr_rate;
	bool video_adaptive;
	uint32_t video_min_bitrate;
	uint32_t session_expires;
	uint32_t session_min_se;
	bool audio_active;
	int16_t *hold_pcm;
	size_t hold_samples;
	uint32_t hold_srate;
	bool suspended;
	bool stop_requested;
	uint64_t t0_ms;
	mtx_t video_mtx;
	cnd_t video_cnd;
	unsigned video_inflight;
	mtx_t life_mtx;
	struct vidsrc_st *preview_src;
	struct bsk_video_sink preview_sink;
	unsigned preview_w;
	unsigned preview_h;
};

struct bsk_op {
	struct le le;
	bsk_op_fn *fn;
	void *arg;
	int ret;
	bool done;
	mtx_t mtx;
	cnd_t cnd;
};

int bsk_run(bsk_engine *engine, bsk_op_fn *fn, void *arg);
bool bsk_on_engine_thread(const bsk_engine *engine);
uint64_t bsk_now_ms(void);
void bsk_emit(bsk_engine *engine, bsk_event *ev);
void bsk_event_init(bsk_event *ev, bsk_event_type type);

void bsk_error_clear(bsk_error *err);
bsk_status bsk_error_set(bsk_error *err, bsk_status status, int sys_errno,
			 uint16_t sip_status, const char *sip_reason,
			 const char *fmt, ...);
bsk_status bsk_status_from_errno(int err);
bool bsk_text_safe(const char *s);
bool bsk_name_safe(const char *s, const char *extra);
int bsk_first_error(int err, int next);

void bsk_log_init(bsk_engine *engine);
void bsk_log_close(bsk_engine *engine);
void bsk_log_emit(bsk_engine *engine, bsk_log_level level,
		  bsk_log_domain domain, const char *line, size_t len);
size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len);
void bsk_sip_trace_handler(bool tx, enum sip_transp tp, const struct sa *src,
			   const struct sa *dst, const uint8_t *pkt, size_t len,
			   void *arg);

struct bsk_account_ctx *bsk_account_find(bsk_engine *engine, bsk_account_id id);
struct bsk_account_ctx *bsk_account_default(bsk_engine *engine);
struct bsk_account_ctx *bsk_account_find_ua(bsk_engine *engine,
					    const struct ua *ua);
void bsk_account_handle_event(bsk_engine *engine, enum bevent_ev ev,
			      struct bevent *event);
void bsk_accounts_flush(bsk_engine *engine);

struct bsk_call_ctx *bsk_call_find(bsk_engine *engine, bsk_call_id id);
struct bsk_call_ctx *bsk_call_find_call(bsk_engine *engine,
					const struct call *call);
void bsk_call_handle_event(bsk_engine *engine, enum bevent_ev ev,
			   struct bevent *event);
void bsk_call_handle_module_event(bsk_engine *engine, const char *text);
void bsk_call_handle_invite(bsk_engine *engine, struct bevent *event);
void bsk_calls_hangup_account(bsk_engine *engine, bsk_account_id account);

struct bsk_ice_info {
	void *sdpm;
	bsk_ice_state state;
	bsk_candidate_type local_type;
	bsk_candidate_type remote_type;
	char local_addr[64];
	char remote_addr[64];
};

bool bsk_ice_parse_event(const char *text, size_t len,
			 struct bsk_ice_info *out);
void bsk_calls_flush(bsk_engine *engine);
void bsk_calls_audio_changed(bsk_engine *engine);
void bsk_calls_rate_tick(bsk_engine *engine);
int bsk_message_init(bsk_engine *engine);
int bsk_audio_init(void);
void bsk_audio_close(void);
void bsk_g722_init(void);
void bsk_g722_close(void);
int bsk_record_init(void);
void bsk_record_close(void);
int bsk_record_start(const struct audio *au, const char *path, void **handle);
int bsk_record_stop(void **handle);
void bsk_calls_recording_failed(bsk_engine *engine, const void *handle);
void bsk_message_close(bsk_engine *engine);

bsk_engine *bsk_global_engine(void);

#define BSK_HOLD_MODULE "bskhold"
int bsk_hold_init(void);
void bsk_hold_close(void);
int bsk_hold_music_load(bsk_engine *engine, const char *path);
bool bsk_call_hold_music(const bsk_engine *engine,
			 const struct bsk_call_ctx *c);

int bsk_tls_install(bsk_engine *engine, struct tls *tls);
typedef void(bsk_trust_cert_h)(const uint8_t *der, size_t len, void *arg);
bool bsk_trust_system(const char *host, const uint8_t *const *derv,
		      const size_t *lenv, size_t count, bsk_trust_cert_h *certh,
		      void *arg);

int bsk_video_init(bsk_engine *engine);
void bsk_video_close(bsk_engine *engine);
void bsk_video_bind_call(struct bsk_call_ctx *c);
void bsk_video_detach_call(bsk_engine *engine, struct bsk_call_ctx *c);

#endif
