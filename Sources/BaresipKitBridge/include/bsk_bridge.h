#ifndef BSK_BRIDGE_H
#define BSK_BRIDGE_H

#include <baresip_kit.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct bsk_bridge_engine_event {
	bsk_engine_state state;
	bsk_error error;
} bsk_bridge_engine_event;

typedef struct bsk_bridge_registration_event {
	bsk_registration_state state;
	bsk_error error;
	uint32_t expires;
} bsk_bridge_registration_event;

typedef struct bsk_bridge_call_state_event {
	bsk_call_state state;
	bsk_error error;
} bsk_bridge_call_state_event;

typedef struct bsk_bridge_media_event {
	bsk_media_event event;
	bsk_media_direction audio_dir;
	bsk_media_direction video_dir;
	char detail[64];
} bsk_bridge_media_event;

typedef struct bsk_bridge_dtmf_event {
	char digit;
	bool end;
	bool via_sip_info;
} bsk_bridge_dtmf_event;

typedef struct bsk_bridge_transfer_event {
	bool failed;
	uint16_t sip_status;
	char target_uri[256];
} bsk_bridge_transfer_event;

typedef struct bsk_bridge_ice_event {
	bsk_ice_state state;
	bsk_candidate_type local_candidate;
	bsk_candidate_type remote_candidate;
	char local_address[64];
	char remote_address[64];
} bsk_bridge_ice_event;

typedef struct bsk_bridge_audio_event {
	bool input_running;
	bool output_running;
	bsk_error error;
} bsk_bridge_audio_event;

typedef struct bsk_bridge_diagnostic_event {
	bsk_log_level level;
	char message[160];
} bsk_bridge_diagnostic_event;

static inline bsk_bridge_engine_event
bsk_bridge_event_engine(const bsk_event *ev)
{
	bsk_bridge_engine_event out = { ev->u.engine.state,
					ev->u.engine.error };
	return out;
}

static inline bsk_bridge_registration_event
bsk_bridge_event_registration(const bsk_event *ev)
{
	bsk_bridge_registration_event out = { ev->u.registration.state,
					      ev->u.registration.error,
					      ev->u.registration.expires };
	return out;
}

static inline bsk_bridge_call_state_event
bsk_bridge_event_call_state(const bsk_event *ev)
{
	bsk_bridge_call_state_event out = { ev->u.call_state.state,
					    ev->u.call_state.error };
	return out;
}

static inline bsk_call_info bsk_bridge_event_call_incoming(const bsk_event *ev)
{
	return ev->u.call_incoming.info;
}

static inline bool
bsk_bridge_event_call_incoming_early_video(const bsk_event *ev)
{
	return ev->u.call_incoming.early_video;
}

static inline bsk_bridge_media_event bsk_bridge_event_media(const bsk_event *ev)
{
	bsk_bridge_media_event out;
	out.event = ev->u.media.event;
	out.audio_dir = ev->u.media.audio_dir;
	out.video_dir = ev->u.media.video_dir;
	__builtin_memcpy(out.detail, ev->u.media.detail, sizeof(out.detail));
	return out;
}

static inline bsk_bridge_dtmf_event bsk_bridge_event_dtmf(const bsk_event *ev)
{
	bsk_bridge_dtmf_event out = { ev->u.dtmf.digit, ev->u.dtmf.end,
				      ev->u.dtmf.via_sip_info };
	return out;
}

static inline bsk_bridge_transfer_event
bsk_bridge_event_transfer(const bsk_event *ev)
{
	bsk_bridge_transfer_event out;
	out.failed = ev->u.transfer.failed;
	out.sip_status = ev->u.transfer.sip_status;
	__builtin_memcpy(out.target_uri, ev->u.transfer.target_uri,
			 sizeof(out.target_uri));
	return out;
}

static inline bsk_call_statistics
bsk_bridge_event_statistics(const bsk_event *ev)
{
	return ev->u.statistics.stats;
}

static inline bsk_bridge_ice_event bsk_bridge_event_ice(const bsk_event *ev)
{
	bsk_bridge_ice_event out;
	out.state = ev->u.ice.state;
	out.local_candidate = ev->u.ice.local_candidate;
	out.remote_candidate = ev->u.ice.remote_candidate;
	__builtin_memcpy(out.local_address, ev->u.ice.local_address,
			 sizeof(out.local_address));
	__builtin_memcpy(out.remote_address, ev->u.ice.remote_address,
			 sizeof(out.remote_address));
	return out;
}

typedef struct bsk_bridge_network_event {
	bool transports_reset;
	char local_address[64];
} bsk_bridge_network_event;

static inline bool bsk_bridge_event_network_reset(const bsk_event *ev)
{
	return ev->u.network.transports_reset;
}

static inline bsk_bridge_network_event
bsk_bridge_event_network(const bsk_event *ev)
{
	bsk_bridge_network_event out;
	out.transports_reset = ev->u.network.transports_reset;
	__builtin_memcpy(out.local_address, ev->u.network.local_address,
			 sizeof(out.local_address));
	return out;
}

static inline void bsk_bridge_make_network_event(bsk_event *ev,
						 bool transports_reset,
						 const char *local_address)
{
	__builtin_memset(ev, 0, sizeof(*ev));
	ev->type = BSK_EVENT_NETWORK;
	ev->u.network.transports_reset = transports_reset;
	if (local_address) {
		size_t i = 0;
		while (local_address[i] &&
		       i + 1 < sizeof(ev->u.network.local_address)) {
			ev->u.network.local_address[i] = local_address[i];
			i++;
		}
	}
}

static inline bsk_bridge_audio_event bsk_bridge_event_audio(const bsk_event *ev)
{
	bsk_bridge_audio_event out = { ev->u.audio.input_running,
				       ev->u.audio.output_running,
				       ev->u.audio.error };
	return out;
}

static inline bsk_bridge_diagnostic_event
bsk_bridge_event_diagnostic(const bsk_event *ev)
{
	bsk_bridge_diagnostic_event out;
	out.level = ev->u.diagnostic.level;
	__builtin_memcpy(out.message, ev->u.diagnostic.message,
			 sizeof(out.message));
	return out;
}

typedef struct bsk_bridge_message_event {
	char from[256];
	char content_type[64];
	const char *body;
	size_t body_len;
} bsk_bridge_message_event;

static inline bsk_bridge_message_event
bsk_bridge_event_message(const bsk_event *ev)
{
	bsk_bridge_message_event out;
	__builtin_memcpy(out.from, ev->u.message.from, sizeof(out.from));
	__builtin_memcpy(out.content_type, ev->u.message.content_type,
			 sizeof(out.content_type));
	out.body = ev->u.message.body;
	out.body_len = ev->u.message.body_len;
	return out;
}

typedef struct bsk_bridge_message_status_event {
	uint64_t message_id;
	bool delivered;
	uint16_t sip_status;
	bsk_error error;
} bsk_bridge_message_status_event;

static inline bsk_bridge_message_status_event
bsk_bridge_event_message_status(const bsk_event *ev)
{
	bsk_bridge_message_status_event out = { ev->u.message_status.message_id,
						ev->u.message_status.delivered,
						ev->u.message_status.sip_status,
						ev->u.message_status.error };
	return out;
}

#ifdef __cplusplus
}
#endif

#endif
