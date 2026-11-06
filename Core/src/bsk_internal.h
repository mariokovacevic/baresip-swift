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

#define BSK_MAX_MODULES 32
#define BSK_MAX_DTMF 64
#define BSK_CPARAMS_MAX 1024

typedef int (bsk_op_fn)(bsk_engine *engine, void *arg);

struct bsk_account_ctx {
	struct le le;
	bsk_account_id id;
	struct ua *ua;
	bsk_registration_state state;
	bool reg_inflight;
	bool registered;
	bool has_pending_cparams;
	char pending_cparams[BSK_CPARAMS_MAX];
	bool pending_reregister;
	bool is_default;
	bool tls;
	uint32_t expires;
	uint64_t reg_started_ms;
};

struct bsk_call_ctx {
	struct le le;
	bsk_call_id id;
	struct call *call;
	bsk_account_id account;
	bsk_call_state state;
	bsk_call_state steady_state;
	bool outgoing;
	bool video;
	bool local_hold;
	bool remote_hold;
	bool rtp_established;
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
	uint32_t ice_gather_count;
	uint32_t ice_gather_snapshot;
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
	char audio_src_dev[128];
	char audio_play_mod[32];
	char audio_play_dev[128];
	uint32_t audio_srate;
	uint32_t audio_channels;
	uint32_t audio_ptime;
	uint32_t jb_min_ms;
	uint32_t jb_max_ms;
	bool jb_adaptive;
	bool voice_processing;
	char video_src_mod[32];
	char video_src_dev[128];
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
	struct list accounts;
	struct list calls;
	uint64_t next_account_id;
	uint64_t next_call_id;
	struct log baresip_log;
	struct tmr tmr_stop;
	struct tmr tmr_running;
	bool audio_active;
	bool suspended;
	bool stop_requested;
	uint64_t t0_ms;
	mtx_t video_mtx;
	struct vidsrc_st *preview_src;
	struct bsk_video_sink preview_sink;
	unsigned preview_w;
	unsigned preview_h;
};

struct bsk_op {
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

void bsk_log_init(bsk_engine *engine);
void bsk_log_close(bsk_engine *engine);
void bsk_log_emit(bsk_engine *engine, bsk_log_level level,
		  bsk_log_domain domain, const char *line, size_t len);
size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len);
void bsk_sip_trace_handler(bool tx, enum sip_transp tp,
			   const struct sa *src, const struct sa *dst,
			   const uint8_t *pkt, size_t len, void *arg);

struct bsk_account_ctx *bsk_account_find(bsk_engine *engine,
					 bsk_account_id id);
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
void bsk_calls_snapshot_ice(bsk_engine *engine);
void bsk_calls_restart_ice(bsk_engine *engine);

bsk_engine *bsk_global_engine(void);

int bsk_tls_install_pins(bsk_engine *engine);

int bsk_video_init(bsk_engine *engine);
void bsk_video_close(bsk_engine *engine);
void bsk_video_bind_call(struct bsk_call_ctx *c);

#endif
