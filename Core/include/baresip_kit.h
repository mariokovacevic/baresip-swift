#ifndef BARESIP_KIT_H
#define BARESIP_KIT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define BSK_EXPORT __declspec(dllexport)
#else
#define BSK_EXPORT __attribute__((visibility("default")))
#endif

#define BSK_ABI_VERSION_MAJOR 0
#define BSK_ABI_VERSION_MINOR 12

typedef struct bsk_engine bsk_engine;

typedef uint64_t bsk_account_id;
typedef uint64_t bsk_call_id;

#define BSK_ID_NONE ((uint64_t)0)

typedef enum bsk_status {
	BSK_OK = 0,
	BSK_ERR_INVALID_ARGUMENT = 1,
	BSK_ERR_INVALID_STATE = 2,
	BSK_ERR_NOT_FOUND = 3,
	BSK_ERR_NO_MEMORY = 4,
	BSK_ERR_UNSUPPORTED = 5,
	BSK_ERR_BUSY = 6,
	BSK_ERR_TIMEOUT = 7,
	BSK_ERR_NETWORK = 8,
	BSK_ERR_TLS = 9,
	BSK_ERR_AUTH = 10,
	BSK_ERR_SIP = 11,
	BSK_ERR_MEDIA = 12,
	BSK_ERR_BUFFER_TOO_SMALL = 13,
	BSK_ERR_INTERNAL = 14
} bsk_status;

typedef struct bsk_error {
	bsk_status status;
	int32_t sys_errno;
	uint16_t sip_status;
	char sip_reason[64];
	char message[160];
} bsk_error;

typedef enum bsk_log_level {
	BSK_LOG_DEBUG = 0,
	BSK_LOG_INFO = 1,
	BSK_LOG_WARNING = 2,
	BSK_LOG_ERROR = 3
} bsk_log_level;

typedef enum bsk_log_domain {
	BSK_LOG_DOMAIN_CORE = 0,
	BSK_LOG_DOMAIN_SIP = 1,
	BSK_LOG_DOMAIN_MEDIA = 2
} bsk_log_domain;

typedef void (*bsk_log_handler)(bsk_log_level level, bsk_log_domain domain,
				const char *line, size_t len, void *user);

typedef enum bsk_engine_state {
	BSK_ENGINE_IDLE = 0,
	BSK_ENGINE_STARTING = 1,
	BSK_ENGINE_READY = 2,
	BSK_ENGINE_RUNNING = 3,
	BSK_ENGINE_STOPPING = 4,
	BSK_ENGINE_STOPPED = 5,
	BSK_ENGINE_FAILED = 6
} bsk_engine_state;

typedef enum bsk_transport {
	BSK_TRANSPORT_UDP = 0,
	BSK_TRANSPORT_TCP = 1,
	BSK_TRANSPORT_TLS = 2,
	BSK_TRANSPORT_WSS = 3
} bsk_transport;

typedef enum bsk_media_encryption {
	BSK_MEDIA_ENC_NONE = 0,
	BSK_MEDIA_ENC_SRTP_OPTIONAL = 1,
	BSK_MEDIA_ENC_SRTP_MANDATORY = 2,
	BSK_MEDIA_ENC_DTLS_SRTP = 3
} bsk_media_encryption;

typedef enum bsk_nat_traversal {
	BSK_NAT_NONE = 0,
	BSK_NAT_STUN = 1,
	BSK_NAT_ICE = 2
} bsk_nat_traversal;

typedef enum bsk_dtmf_mode {
	BSK_DTMF_AUTO = 0,
	BSK_DTMF_RTP_EVENT = 1,
	BSK_DTMF_SIP_INFO = 2
} bsk_dtmf_mode;

typedef enum bsk_registration_state {
	BSK_REG_NONE = 0,
	BSK_REG_REGISTERING = 1,
	BSK_REG_REGISTERED = 2,
	BSK_REG_UNREGISTERING = 3,
	BSK_REG_FAILED = 4
} bsk_registration_state;

typedef enum bsk_call_state {
	BSK_CALL_INCOMING = 0,
	BSK_CALL_OUTGOING_INIT = 1,
	BSK_CALL_OUTGOING_RINGING = 2,
	BSK_CALL_EARLY_MEDIA = 3,
	BSK_CALL_CONNECTED = 4,
	BSK_CALL_STREAMS_RUNNING = 5,
	BSK_CALL_PAUSING = 6,
	BSK_CALL_PAUSED = 7,
	BSK_CALL_RESUMING = 8,
	BSK_CALL_PAUSED_BY_REMOTE = 9,
	BSK_CALL_UPDATING = 10,
	BSK_CALL_ENDED = 11,
	BSK_CALL_FAILED = 12,
	BSK_CALL_RELEASED = 13
} bsk_call_state;

typedef enum bsk_call_end_reason {
	BSK_END_NORMAL = 0,
	BSK_END_ANSWERED_ELSEWHERE = 1,
	BSK_END_DECLINED_ELSEWHERE = 2,
	BSK_END_REPLACED = 3
} bsk_call_end_reason;

typedef enum bsk_media_direction {
	BSK_DIR_INACTIVE = 0,
	BSK_DIR_SENDONLY = 1,
	BSK_DIR_RECVONLY = 2,
	BSK_DIR_SENDRECV = 3
} bsk_media_direction;

typedef enum bsk_ice_state {
	BSK_ICE_NONE = 0,
	BSK_ICE_GATHERING = 1,
	BSK_ICE_CHECKING = 2,
	BSK_ICE_CONNECTED = 3,
	BSK_ICE_FAILED = 4
} bsk_ice_state;

typedef enum bsk_candidate_type {
	BSK_CAND_HOST = 0,
	BSK_CAND_SRFLX = 1,
	BSK_CAND_PRFLX = 2,
	BSK_CAND_RELAY = 3
} bsk_candidate_type;

typedef enum bsk_pixel_format {
	BSK_PIX_NV12 = 0,
	BSK_PIX_I420 = 1,
	BSK_PIX_BGRA = 2
} bsk_pixel_format;

#define BSK_TLS_VERSION_1_2 0x0303
#define BSK_TLS_VERSION_1_3 0x0304

typedef struct bsk_tls_config {
	const char *ca_pem;
	size_t ca_pem_len;
	const char *client_cert_pem;
	size_t client_cert_pem_len;
	const char *const *pinned_spki_sha256_base64;
	size_t pinned_count;
	const char *cipher_list;
	/* The lowest TLS version accepted: BSK_TLS_VERSION_1_2 or
	 * BSK_TLS_VERSION_1_3, the version numbers of the TLS wire format.
	 * 0 means TLS 1.2. bsk_engine_create rejects any other value. */
	int min_version;
	bool insecure_skip_verify;
} bsk_tls_config;

typedef struct bsk_turn_server {
	const char *uri;
	const char *username;
	const char *password;
} bsk_turn_server;

typedef struct bsk_nat_config {
	bsk_nat_traversal mode;
	const char *stun_uri;
	const bsk_turn_server *turn_servers;
	size_t turn_count;
	uint32_t rtp_timeout_ms;
} bsk_nat_config;

typedef struct bsk_audio_config {
	const char *source_module;
	const char *source_device;
	const char *player_module;
	const char *player_device;
	uint32_t sample_rate;
	uint32_t channels;
	uint32_t ptime_ms;
	uint32_t jitter_buffer_min_ms;
	uint32_t jitter_buffer_max_ms;
	bool jitter_buffer_adaptive;
	const char *const *codecs;
	size_t codec_count;
} bsk_audio_config;

typedef struct bsk_video_config {
	const char *source_module;
	const char *source_device;
	uint32_t width;
	uint32_t height;
	uint32_t fps;
	uint32_t bitrate_bps;
	const char *const *codecs;
	size_t codec_count;
} bsk_video_config;

typedef struct bsk_engine_config {
	uint32_t size;
	const char *user_agent;
	const char *instance_uuid;
	const char *network_interface;
	const char *const *modules;
	size_t module_count;
	const char *extra_config;
	bool ipv6;
	uint16_t rtp_port_min;
	uint16_t rtp_port_max;
	uint32_t max_calls;
	bsk_audio_config audio;
	bsk_video_config video;
	bsk_tls_config tls;
	bsk_log_level log_level;
	bool log_sip_trace;
	bool ice_relay_only;
	bool video_adaptive_bitrate;
	uint32_t video_min_bitrate_bps;
	/* A 16-bit PCM WAV file, mono or stereo, 8 to 48 kHz, that a held call
	 * plays to the other side in a loop instead of the microphone. NULL
	 * sends nothing while on hold. */
	const char *hold_music_path;
	/* The RFC 4028 session timer in seconds that calls offer and accept:
	 * the refresher renews the session with UPDATE or re-INVITE, the
	 * other side hangs up with BYE when it is not renewed. 0 keeps
	 * session timers off. */
	uint32_t session_expires;
	/* The smallest session interval accepted in seconds: at least 90,
	 * the minimum of RFC 4028, and at most session_expires; 0 means 90.
	 * bsk_engine_create rejects other values, so session_expires is
	 * 0 or at least 90 too. */
	uint32_t session_min_se;
} bsk_engine_config;

typedef struct bsk_contact_param {
	const char *name;
	const char *value;
} bsk_contact_param;

typedef struct bsk_account_config {
	uint32_t size;
	const char *aor;
	const char *display_name;
	const char *registrar;
	const char *outbound_proxy;
	bsk_transport transport;
	const char *auth_user;
	const char *auth_password;
	uint32_t register_expires;
	bool sip_outbound;
	bsk_media_encryption media_encryption;
	bsk_nat_config nat;
	bsk_dtmf_mode dtmf_mode;
	const bsk_contact_param *contact_params;
	size_t contact_param_count;
	const char *const *audio_codecs;
	size_t audio_codec_count;
	const char *const *video_codecs;
	size_t video_codec_count;
	bool answer_early_media;
	bool reject_transfers;
	bool rtcp_mux;
	bool nat_pinhole;
	bool vfu_info;
	const char *const *incoming_headers;
	size_t incoming_header_count;
} bsk_account_config;

typedef struct bsk_call_info {
	bsk_call_id id;
	bsk_account_id account;
	bsk_call_state state;
	bool outgoing;
	bool has_video;
	bsk_media_direction audio_dir;
	bsk_media_direction video_dir;
	char sip_call_id[128];
	char remote_uri[256];
	char remote_display_name[128];
	char audio_codec[32];
	char video_codec[32];
	uint32_t setup_ms;
	uint32_t duration_s;
	bool microphone_muted;
	/* The call this one takes over, or BSK_ID_NONE: an incoming call whose
	 * INVITE replaced an established call (RFC 3891), or the outgoing call
	 * that follows a transfer of that call (RFC 3515). The call it takes
	 * over ends with BSK_END_REPLACED. */
	bsk_call_id replaces;
} bsk_call_info;

typedef struct bsk_stream_statistics {
	uint32_t tx_packets;
	uint32_t rx_packets;
	uint64_t tx_bytes;
	uint64_t rx_bytes;
	/* Packets lost since the stream started, never negative: the
	 * cumulative loss of RTCP (RFC 3550) counts duplicates against
	 * losses and can drop below zero, which is reported as 0. */
	int32_t rx_lost;
	uint32_t rx_fraction_lost_permille;
	uint32_t rx_jitter_ms;
	uint32_t rtt_ms;
	uint32_t tx_bitrate_bps;
	uint32_t rx_bitrate_bps;
	uint32_t jitter_buffer_delay_ms;
	bool secure;
} bsk_stream_statistics;

typedef struct bsk_call_statistics {
	bsk_call_id id;
	bsk_stream_statistics audio;
	bsk_stream_statistics video;
	bsk_ice_state ice_state;
	bsk_candidate_type local_candidate;
	bsk_candidate_type remote_candidate;
	char local_address[64];
	char remote_address[64];
	float mos_estimate;
	uint32_t video_target_bitrate_bps;
} bsk_call_statistics;

typedef enum bsk_event_type {
	BSK_EVENT_ENGINE_STATE = 0,
	BSK_EVENT_REGISTRATION = 1,
	BSK_EVENT_CALL_STATE = 2,
	BSK_EVENT_CALL_INCOMING = 3,
	BSK_EVENT_CALL_MEDIA = 4,
	BSK_EVENT_CALL_DTMF = 5,
	BSK_EVENT_CALL_TRANSFER = 6,
	BSK_EVENT_CALL_STATISTICS = 7,
	BSK_EVENT_ICE = 8,
	BSK_EVENT_NETWORK = 9,
	BSK_EVENT_AUDIO = 10,
	/* Reserved for diagnostics; this revision never emits it. */
	BSK_EVENT_DIAGNOSTIC = 11,
	BSK_EVENT_MESSAGE = 12,
	BSK_EVENT_MESSAGE_STATUS = 13
} bsk_event_type;

typedef enum bsk_media_event {
	BSK_MEDIA_AUDIO_STARTED = 0,
	BSK_MEDIA_REMOTE_HOLD = 4,
	BSK_MEDIA_REMOTE_RESUME = 5,
	BSK_MEDIA_ENCRYPTION_ESTABLISHED = 6,
	BSK_MEDIA_KEYFRAME_REQUESTED = 8,
	BSK_MEDIA_EARLY_VIDEO_AVAILABLE = 9,
	BSK_MEDIA_RECORDING_STARTED = 10,
	BSK_MEDIA_RECORDING_STOPPED = 11
} bsk_media_event;

typedef struct bsk_event {
	bsk_event_type type;
	uint64_t timestamp_ms;
	bsk_account_id account;
	bsk_call_id call;
	union {
		struct {
			bsk_engine_state state;
			bsk_error error;
		} engine;
		struct {
			bsk_registration_state state;
			bsk_error error;
			uint32_t expires;
		} registration;
		struct {
			bsk_call_state state;
			bsk_error error;
			/* For BSK_CALL_ENDED of an incoming call that rang: whether
			 * another device answered or declined it, as the Reason
			 * header of the CANCEL says (RFC 3326). BSK_END_REPLACED
			 * when a call with this call's id in
			 * bsk_call_info.replaces takes it over. */
			bsk_call_end_reason end_reason;
		} call_state;
		struct {
			bsk_call_info info;
			bool early_video;
		} call_incoming;
		struct {
			bsk_media_event event;
			bsk_media_direction audio_dir;
			bsk_media_direction video_dir;
			char detail[64];
		} media;
		struct {
			char digit;
			bool end;
			bool via_sip_info;
		} dtmf;
		struct {
			bool failed;
			uint16_t sip_status;
			char target_uri[256];
		} transfer;
		struct {
			bsk_call_statistics stats;
		} statistics;
		struct {
			bsk_ice_state state;
			bsk_candidate_type local_candidate;
			bsk_candidate_type remote_candidate;
			char local_address[64];
			char remote_address[64];
		} ice;
		struct {
			bool transports_reset;
			char local_address[64];
		} network;
		struct {
			bool input_running;
			bool output_running;
			bsk_error error;
		} audio;
		struct {
			bsk_log_level level;
			char message[160];
		} diagnostic;
		struct {
			char from[256];
			char content_type[64];
			const char *body;
			size_t body_len;
		} message;
		struct {
			uint64_t message_id;
			bool delivered;
			uint16_t sip_status;
			bsk_error error;
		} message_status;
	} u;
} bsk_event;

typedef void (*bsk_event_handler)(bsk_engine *engine, const bsk_event *event,
				  void *user);

typedef struct bsk_video_frame {
	bsk_pixel_format format;
	uint32_t width;
	uint32_t height;
	const uint8_t *planes[3];
	uint32_t strides[3];
	uint64_t timestamp_us;
	int rotation_degrees;
	void *native_buffer;
} bsk_video_frame;

typedef void (*bsk_video_frame_handler)(bsk_engine *engine, bsk_call_id call,
					bool local,
					const bsk_video_frame *frame,
					void *user);

typedef struct bsk_video_sink {
	bsk_video_frame_handler on_frame;
	void (*on_size)(bsk_engine *engine, bsk_call_id call, bool local,
			uint32_t width, uint32_t height, void *user);
	void *user;
} bsk_video_sink;

#define BSK_ENGINE_CONFIG_INIT                      \
	{                                           \
		(uint32_t)sizeof(bsk_engine_config) \
	}
#define BSK_ACCOUNT_CONFIG_INIT                      \
	{                                            \
		(uint32_t)sizeof(bsk_account_config) \
	}

BSK_EXPORT uint32_t bsk_abi_version(void);
BSK_EXPORT const char *bsk_version_string(void);
BSK_EXPORT const char *bsk_status_string(bsk_status status);

BSK_EXPORT bsk_status bsk_engine_create(const bsk_engine_config *config,
					bsk_event_handler handler, void *user,
					bsk_engine **out_engine,
					bsk_error *err);
/* Stops the engine if needed and frees it. On the engine thread (from an
 * event, log or remote video frame callback) it does nothing and returns
 * BSK_ERR_INVALID_STATE. See Docs/C-ABI.md for the threading rules. */
BSK_EXPORT bsk_status bsk_engine_destroy(bsk_engine *engine);
BSK_EXPORT void bsk_engine_set_log_handler(bsk_engine *engine,
					   bsk_log_handler handler, void *user);
BSK_EXPORT void bsk_engine_set_event_handler(bsk_engine *engine,
					     bsk_event_handler handler,
					     void *user);
BSK_EXPORT bsk_status bsk_engine_start(bsk_engine *engine, bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_stop(bsk_engine *engine, uint32_t timeout_ms,
				      bsk_error *err);
BSK_EXPORT bsk_engine_state bsk_engine_get_state(const bsk_engine *engine);
BSK_EXPORT bool bsk_engine_is_engine_thread(const bsk_engine *engine);
BSK_EXPORT bsk_status bsk_engine_prepare_for_push_wakeup(bsk_engine *engine,
							 bsk_error *err);
/* Has no effect in this revision and returns BSK_OK: transports,
 * registrations and calls stay as they are. bsk_engine_resume resets the
 * transports and re-registers whether or not suspend was called. */
BSK_EXPORT bsk_status bsk_engine_suspend(bsk_engine *engine, bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_resume(bsk_engine *engine, bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_network_changed(bsk_engine *engine,
						 bool reregister,
						 bool update_calls,
						 bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_audio_session_activated(bsk_engine *engine,
							 bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_audio_session_deactivated(bsk_engine *engine,
							   bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_audio_route_changed(bsk_engine *engine,
						     bsk_error *err);
BSK_EXPORT bsk_status bsk_engine_audio_interruption(bsk_engine *engine,
						    bool began, bsk_error *err);

BSK_EXPORT bsk_status bsk_account_add(bsk_engine *engine,
				      const bsk_account_config *config,
				      bsk_account_id *out_id, bsk_error *err);
BSK_EXPORT bsk_status bsk_account_remove(bsk_engine *engine, bsk_account_id id,
					 bsk_error *err);
BSK_EXPORT bsk_status bsk_account_set_default(bsk_engine *engine,
					      bsk_account_id id,
					      bsk_error *err);
BSK_EXPORT bsk_status bsk_account_register(bsk_engine *engine,
					   bsk_account_id id, bsk_error *err);
BSK_EXPORT bsk_status bsk_account_unregister(bsk_engine *engine,
					     bsk_account_id id, bsk_error *err);
BSK_EXPORT bsk_status bsk_account_set_credentials(bsk_engine *engine,
						  bsk_account_id id,
						  const char *auth_user,
						  const char *auth_password,
						  bsk_error *err);
BSK_EXPORT bsk_status bsk_account_set_contact_params(
	bsk_engine *engine, bsk_account_id id, const bsk_contact_param *params,
	size_t count, bool reregister_now, bsk_error *err);
BSK_EXPORT bsk_status
bsk_account_get_registration_state(const bsk_engine *engine, bsk_account_id id,
				   bsk_registration_state *out_state);
BSK_EXPORT size_t bsk_account_list(const bsk_engine *engine,
				   bsk_account_id *ids,
				   bsk_registration_state *states,
				   size_t capacity);
BSK_EXPORT bsk_status bsk_contact_params_encode(const bsk_contact_param *params,
						size_t count, char *buf,
						size_t buf_len,
						size_t *out_len);

BSK_EXPORT bsk_status bsk_call_make(bsk_engine *engine, bsk_account_id account,
				    const char *destination, bool video,
				    bsk_call_id *out_id, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_make_media(bsk_engine *engine,
					  bsk_account_id account,
					  const char *destination, bool audio,
					  bool video, bsk_call_id *out_id,
					  bsk_error *err);
BSK_EXPORT bsk_status bsk_call_answer(bsk_engine *engine, bsk_call_id call,
				      bool video, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_answer_media(bsk_engine *engine,
					    bsk_call_id call, bool audio,
					    bool video, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_progress(bsk_engine *engine, bsk_call_id call,
					bool early_video, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_progress_media(bsk_engine *engine,
					      bsk_call_id call,
					      bool early_audio,
					      bool early_video, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_reject(bsk_engine *engine, bsk_call_id call,
				      uint16_t sip_status, const char *reason,
				      bsk_error *err);
BSK_EXPORT bsk_status bsk_call_hangup(bsk_engine *engine, bsk_call_id call,
				      bsk_error *err);
BSK_EXPORT bsk_status bsk_call_hold(bsk_engine *engine, bsk_call_id call,
				    bool hold, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_active(bsk_engine *engine, bsk_call_id call,
					  bsk_error *err);
BSK_EXPORT bsk_status bsk_call_send_dtmf(bsk_engine *engine, bsk_call_id call,
					 const char *digits,
					 uint32_t duration_ms, uint32_t gap_ms,
					 bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_microphone_muted(bsk_engine *engine,
						    bsk_call_id call,
						    bool muted, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_audio_direction(bsk_engine *engine,
						   bsk_call_id call,
						   bsk_media_direction dir,
						   bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_video_direction(bsk_engine *engine,
						   bsk_call_id call,
						   bsk_media_direction dir,
						   bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_camera(bsk_engine *engine, bsk_call_id call,
					  const char *device, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_request_keyframe(bsk_engine *engine,
						bsk_call_id call,
						bsk_error *err);
BSK_EXPORT bsk_status bsk_call_set_video_max_bitrate(bsk_engine *engine,
						     bsk_call_id call,
						     uint32_t bitrate_bps,
						     bsk_error *err);
BSK_EXPORT bsk_status bsk_call_restart_ice(bsk_engine *engine, bsk_call_id call,
					   bsk_error *err);
BSK_EXPORT bsk_status bsk_call_record_start(bsk_engine *engine,
					    bsk_call_id call, const char *path,
					    bsk_error *err);
BSK_EXPORT bsk_status bsk_call_record_stop(bsk_engine *engine, bsk_call_id call,
					   bsk_error *err);
BSK_EXPORT bsk_status bsk_call_transfer_attended(bsk_engine *engine,
						 bsk_call_id call,
						 bsk_call_id target_call,
						 bsk_error *err);
BSK_EXPORT bsk_status bsk_message_send(bsk_engine *engine,
				       bsk_account_id account,
				       const char *peer_uri, const char *text,
				       uint64_t *out_message_id,
				       bsk_error *err);
BSK_EXPORT bsk_status bsk_call_transfer(bsk_engine *engine, bsk_call_id call,
					const char *target_uri, bsk_error *err);
BSK_EXPORT bsk_status bsk_call_get_info(const bsk_engine *engine,
					bsk_call_id call, bsk_call_info *out);
BSK_EXPORT bsk_status bsk_call_get_header(const bsk_engine *engine,
					  bsk_call_id call, const char *name,
					  char *value, size_t value_size);
BSK_EXPORT bsk_status bsk_call_get_statistics(const bsk_engine *engine,
					      bsk_call_id call,
					      bsk_call_statistics *out);
BSK_EXPORT size_t bsk_call_list(const bsk_engine *engine, bsk_call_id *ids,
				size_t capacity);
BSK_EXPORT bsk_status bsk_call_set_video_sink(bsk_engine *engine,
					      bsk_call_id call, bool local,
					      const bsk_video_sink *sink,
					      bsk_error *err);

BSK_EXPORT bsk_status bsk_video_preview_start(bsk_engine *engine,
					      const char *device,
					      const bsk_video_sink *sink,
					      bsk_error *err);
BSK_EXPORT bsk_status bsk_video_preview_stop(bsk_engine *engine,
					     bsk_error *err);
BSK_EXPORT size_t bsk_video_list_devices(const bsk_engine *engine, char *buf,
					 size_t buf_len);

BSK_EXPORT size_t bsk_capabilities(char *buf, size_t buf_len);

#ifdef __cplusplus
}
#endif

#endif
