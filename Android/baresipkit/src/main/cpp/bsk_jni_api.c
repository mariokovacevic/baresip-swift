#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "baresip_kit.h"
#include "bsk_jni.h"

#define JNI_FN(name) \
	Java_io_github_mariokovacevic_baresipkit_internal_Native_##name

static bsk_engine *engine_of(jlong handle)
{
	struct bsk_jni_engine *owner =
		(struct bsk_jni_engine *)(intptr_t)handle;
	return owner ? owner->engine : NULL;
}

static jbyteArray bytes_field(JNIEnv *env, jobject obj, const char *name)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID field = (*env)->GetFieldID(env, cls, name, "[B");
	(*env)->DeleteLocalRef(env, cls);
	return field ? (*env)->GetObjectField(env, obj, field) : NULL;
}

static jobjectArray strings_field(JNIEnv *env, jobject obj, const char *name)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID field = (*env)->GetFieldID(env, cls, name, "[[B");
	(*env)->DeleteLocalRef(env, cls);
	return field ? (*env)->GetObjectField(env, obj, field) : NULL;
}

static jint int_field(JNIEnv *env, jobject obj, const char *name)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID field = (*env)->GetFieldID(env, cls, name, "I");
	(*env)->DeleteLocalRef(env, cls);
	return field ? (*env)->GetIntField(env, obj, field) : 0;
}

static bool bool_field(JNIEnv *env, jobject obj, const char *name)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID field = (*env)->GetFieldID(env, cls, name, "Z");
	(*env)->DeleteLocalRef(env, cls);
	return field ? (*env)->GetBooleanField(env, obj, field) : false;
}

static const char *cstr(struct bsk_jni_arena *arena, jobject obj,
			const char *name)
{
	return bsk_jni_bytes(arena, bytes_field(arena->env, obj, name), NULL);
}

static const char *const *cstrs(struct bsk_jni_arena *arena, jobject obj,
				const char *name, size_t *count)
{
	return bsk_jni_strings(arena, strings_field(arena->env, obj, name),
			       count);
}

static bool missing_field(JNIEnv *env)
{
	return (*env)->ExceptionCheck(env);
}

static void read_engine_config(struct bsk_jni_arena *arena, jobject obj,
			       bsk_engine_config *cfg)
{
	JNIEnv *env = arena->env;
	cfg->user_agent = cstr(arena, obj, "userAgent");
	cfg->instance_uuid = cstr(arena, obj, "instanceUuid");
	cfg->network_interface = cstr(arena, obj, "networkInterface");
	cfg->modules = cstrs(arena, obj, "modules", &cfg->module_count);
	cfg->extra_config = cstr(arena, obj, "extraConfig");
	cfg->ipv6 = bool_field(env, obj, "ipv6");
	cfg->rtp_port_min = (uint16_t)int_field(env, obj, "rtpPortMin");
	cfg->rtp_port_max = (uint16_t)int_field(env, obj, "rtpPortMax");
	cfg->max_calls = (uint32_t)int_field(env, obj, "maxCalls");
	cfg->log_level = (bsk_log_level)int_field(env, obj, "logLevel");
	cfg->log_sip_trace = bool_field(env, obj, "logSipTrace");
	cfg->ice_relay_only = bool_field(env, obj, "iceRelayOnly");
	cfg->video_adaptive_bitrate =
		bool_field(env, obj, "videoAdaptiveBitrate");
	cfg->video_min_bitrate_bps =
		(uint32_t)int_field(env, obj, "videoMinBitrate");
	cfg->hold_music_path = cstr(arena, obj, "holdMusicPath");
	cfg->session_expires = (uint32_t)int_field(env, obj, "sessionExpires");
	cfg->session_min_se = (uint32_t)int_field(env, obj, "sessionMinSe");

	cfg->audio.source_module = cstr(arena, obj, "audioSourceModule");
	cfg->audio.source_device = cstr(arena, obj, "audioSourceDevice");
	cfg->audio.player_module = cstr(arena, obj, "audioPlayerModule");
	cfg->audio.player_device = cstr(arena, obj, "audioPlayerDevice");
	cfg->audio.sample_rate = (uint32_t)int_field(env, obj, "sampleRate");
	cfg->audio.channels = (uint32_t)int_field(env, obj, "channels");
	cfg->audio.ptime_ms = (uint32_t)int_field(env, obj, "ptimeMs");
	cfg->audio.jitter_buffer_min_ms =
		(uint32_t)int_field(env, obj, "jitterBufferMinMs");
	cfg->audio.jitter_buffer_max_ms =
		(uint32_t)int_field(env, obj, "jitterBufferMaxMs");
	cfg->audio.jitter_buffer_adaptive =
		bool_field(env, obj, "jitterBufferAdaptive");
	cfg->audio.codecs =
		cstrs(arena, obj, "audioCodecs", &cfg->audio.codec_count);

	cfg->video.source_module = cstr(arena, obj, "videoSourceModule");
	cfg->video.source_device = cstr(arena, obj, "videoSourceDevice");
	cfg->video.width = (uint32_t)int_field(env, obj, "videoWidth");
	cfg->video.height = (uint32_t)int_field(env, obj, "videoHeight");
	cfg->video.fps = (uint32_t)int_field(env, obj, "videoFps");
	cfg->video.bitrate_bps = (uint32_t)int_field(env, obj, "videoBitrate");
	cfg->video.codecs =
		cstrs(arena, obj, "videoCodecs", &cfg->video.codec_count);

	cfg->tls.ca_pem = bsk_jni_bytes(arena, bytes_field(env, obj, "caPem"),
					&cfg->tls.ca_pem_len);
	cfg->tls.client_cert_pem =
		bsk_jni_bytes(arena, bytes_field(env, obj, "clientCertPem"),
			      &cfg->tls.client_cert_pem_len);
	cfg->tls.pinned_spki_sha256_base64 =
		cstrs(arena, obj, "pins", &cfg->tls.pinned_count);
	cfg->tls.cipher_list = cstr(arena, obj, "cipherList");
	cfg->tls.min_version = int_field(env, obj, "tlsMinVersion");
	cfg->tls.insecure_skip_verify =
		bool_field(env, obj, "insecureSkipVerify");
}

static const bsk_contact_param *contact_params(struct bsk_jni_arena *arena,
					       jobjectArray names,
					       jobjectArray values,
					       size_t *out_count)
{
	size_t count = 0, value_count = 0;
	const char *const *n = bsk_jni_strings(arena, names, &count);
	const char *const *v = bsk_jni_strings(arena, values, &value_count);
	*out_count = 0;
	if (!count || value_count != count)
		return NULL;
	bsk_contact_param *params =
		bsk_jni_alloc(arena, sizeof(bsk_contact_param) * count);
	if (!params)
		return NULL;
	for (size_t i = 0; i < count; i++) {
		params[i].name = n[i];
		params[i].value = v[i];
	}
	*out_count = count;
	return params;
}

static void read_account_config(struct bsk_jni_arena *arena, jobject obj,
				bsk_account_config *cfg)
{
	JNIEnv *env = arena->env;
	cfg->aor = cstr(arena, obj, "aor");
	cfg->display_name = cstr(arena, obj, "displayName");
	cfg->registrar = cstr(arena, obj, "registrar");
	cfg->outbound_proxy = cstr(arena, obj, "outboundProxy");
	cfg->transport = (bsk_transport)int_field(env, obj, "transport");
	cfg->auth_user = cstr(arena, obj, "authUser");
	cfg->auth_password = cstr(arena, obj, "authPassword");
	cfg->register_expires = (uint32_t)int_field(env, obj, "expires");
	cfg->sip_outbound = bool_field(env, obj, "sipOutbound");
	cfg->media_encryption =
		(bsk_media_encryption)int_field(env, obj, "mediaEncryption");
	cfg->dtmf_mode = (bsk_dtmf_mode)int_field(env, obj, "dtmfMode");
	cfg->contact_params =
		contact_params(arena, strings_field(env, obj, "contactNames"),
			       strings_field(env, obj, "contactValues"),
			       &cfg->contact_param_count);
	cfg->audio_codecs =
		cstrs(arena, obj, "audioCodecs", &cfg->audio_codec_count);
	cfg->video_codecs =
		cstrs(arena, obj, "videoCodecs", &cfg->video_codec_count);
	cfg->answer_early_media = bool_field(env, obj, "answerEarlyMedia");
	cfg->reject_transfers = bool_field(env, obj, "rejectTransfers");
	cfg->rtcp_mux = bool_field(env, obj, "rtcpMux");
	cfg->nat_pinhole = bool_field(env, obj, "natPinhole");
	cfg->vfu_info = bool_field(env, obj, "vfuInfo");
	cfg->incoming_headers = cstrs(arena, obj, "incomingHeaders",
				      &cfg->incoming_header_count);

	cfg->nat.mode = (bsk_nat_traversal)int_field(env, obj, "natMode");
	cfg->nat.stun_uri = cstr(arena, obj, "stunUri");
	cfg->nat.rtp_timeout_ms = (uint32_t)int_field(env, obj, "rtpTimeoutMs");
	const char *turn = cstr(arena, obj, "turnUri");
	if (turn) {
		bsk_turn_server *server =
			bsk_jni_alloc(arena, sizeof(bsk_turn_server));
		if (server) {
			server->uri = turn;
			server->username = cstr(arena, obj, "turnUsername");
			server->password = cstr(arena, obj, "turnPassword");
			cfg->nat.turn_servers = server;
			cfg->nat.turn_count = 1;
		}
	}
}

JNIEXPORT jstring JNICALL JNI_FN(version)(JNIEnv *env, jclass cls)
{
	(void)cls;
	return bsk_jni_string(env, bsk_version_string());
}

JNIEXPORT jint JNICALL JNI_FN(abiVersion)(JNIEnv *env, jclass cls)
{
	(void)env;
	(void)cls;
	return (jint)bsk_abi_version();
}

JNIEXPORT jstring JNICALL JNI_FN(capabilities)(JNIEnv *env, jclass cls)
{
	(void)cls;
	size_t needed = bsk_capabilities(NULL, 0);
	char *buf = calloc(1, needed + 1);
	if (!buf)
		return NULL;
	bsk_capabilities(buf, needed + 1);
	jstring result = bsk_jni_string(env, buf);
	free(buf);
	return result;
}

JNIEXPORT jstring JNICALL JNI_FN(encodeContactParameters)(JNIEnv *env,
							  jclass cls,
							  jobjectArray names,
							  jobjectArray values)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_jni_arena_init(&arena, env);
	size_t count = 0;
	const bsk_contact_param *params =
		contact_params(&arena, names, values, &count);
	size_t needed = 0;
	jstring result = NULL;
	bsk_status status =
		bsk_contact_params_encode(params, count, NULL, 0, &needed);
	if (status == BSK_OK) {
		char *buf = calloc(1, needed + 1);
		status = buf ? bsk_contact_params_encode(params, count, buf,
							 needed + 1, NULL)
			     : BSK_ERR_NO_MEMORY;
		if (status == BSK_OK)
			result = bsk_jni_string(env, buf);
		free(buf);
	}
	bsk_jni_arena_release(&arena);
	if (status != BSK_OK) {
		bsk_error err;
		memset(&err, 0, sizeof(err));
		strncpy(err.message, "invalid contact parameters",
			sizeof(err.message) - 1);
		bsk_jni_throw(env, status, &err);
	}
	return result;
}

JNIEXPORT jlong JNICALL JNI_FN(engineCreate)(JNIEnv *env, jclass cls,
					     jobject owner, jobject config)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_engine_config cfg;
	bsk_error err;
	bsk_engine *engine = NULL;
	memset(&cfg, 0, sizeof(cfg));
	cfg.size = (uint32_t)sizeof(cfg);
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	read_engine_config(&arena, config, &cfg);
	if (missing_field(env)) {
		bsk_jni_arena_release(&arena);
		return 0;
	}
	bsk_status status = bsk_engine_create(&cfg, NULL, NULL, &engine, &err);
	bsk_jni_arena_release(&arena);
	if (!bsk_jni_check(env, status, &err))
		return 0;
	struct bsk_jni_engine *wrapper = calloc(1, sizeof(*wrapper));
	if (!wrapper) {
		bsk_engine_destroy(engine);
		bsk_jni_throw(env, BSK_ERR_NO_MEMORY, NULL);
		return 0;
	}
	wrapper->engine = engine;
	wrapper->owner = (*env)->NewGlobalRef(env, owner);
	bsk_jni_install_callbacks(wrapper);
	return (jlong)(intptr_t)wrapper;
}

JNIEXPORT void JNICALL JNI_FN(engineDestroy)(JNIEnv *env, jclass cls,
					     jlong handle)
{
	(void)cls;
	struct bsk_jni_engine *wrapper =
		(struct bsk_jni_engine *)(intptr_t)handle;
	if (!wrapper)
		return;
	bsk_jni_remove_callbacks(wrapper);
	bsk_engine_destroy(wrapper->engine);
	(*env)->DeleteGlobalRef(env, wrapper->owner);
	free(wrapper);
}

#define ENGINE_CALL(name, call)                                          \
	JNIEXPORT void JNICALL JNI_FN(name)(JNIEnv * env, jclass cls,    \
					    jlong handle)                \
	{                                                                \
		(void)cls;                                               \
		bsk_error err;                                           \
		memset(&err, 0, sizeof(err));                            \
		bsk_jni_check(env, call(engine_of(handle), &err), &err); \
	}

ENGINE_CALL(engineStart, bsk_engine_start)
ENGINE_CALL(enginePrepareForPushWakeup, bsk_engine_prepare_for_push_wakeup)
ENGINE_CALL(engineSuspend, bsk_engine_suspend)
ENGINE_CALL(engineResume, bsk_engine_resume)
ENGINE_CALL(engineAudioSessionActivated, bsk_engine_audio_session_activated)
ENGINE_CALL(engineAudioSessionDeactivated, bsk_engine_audio_session_deactivated)
ENGINE_CALL(engineAudioRouteChanged, bsk_engine_audio_route_changed)

JNIEXPORT void JNICALL JNI_FN(engineStop)(JNIEnv *env, jclass cls, jlong handle,
					  jint timeout_ms)
{
	(void)cls;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_check(
		env,
		bsk_engine_stop(engine_of(handle), (uint32_t)timeout_ms, &err),
		&err);
}

JNIEXPORT jint JNICALL JNI_FN(engineState)(JNIEnv *env, jclass cls,
					   jlong handle)
{
	(void)env;
	(void)cls;
	return (jint)bsk_engine_get_state(engine_of(handle));
}

JNIEXPORT jboolean JNICALL JNI_FN(engineIsEngineThread)(JNIEnv *env, jclass cls,
							jlong handle)
{
	(void)env;
	(void)cls;
	return bsk_engine_is_engine_thread(engine_of(handle));
}

JNIEXPORT void JNICALL JNI_FN(engineNetworkChanged)(JNIEnv *env, jclass cls,
						    jlong handle,
						    jboolean reregister,
						    jboolean update_calls)
{
	(void)cls;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_check(env,
		      bsk_engine_network_changed(engine_of(handle), reregister,
						 update_calls, &err),
		      &err);
}

JNIEXPORT void JNICALL JNI_FN(engineAudioInterruption)(JNIEnv *env, jclass cls,
						       jlong handle,
						       jboolean began)
{
	(void)cls;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_check(
		env,
		bsk_engine_audio_interruption(engine_of(handle), began, &err),
		&err);
}

JNIEXPORT jlong JNICALL JNI_FN(accountAdd)(JNIEnv *env, jclass cls,
					   jlong handle, jobject config)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_account_config cfg;
	bsk_error err;
	bsk_account_id id = 0;
	memset(&cfg, 0, sizeof(cfg));
	cfg.size = (uint32_t)sizeof(cfg);
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	read_account_config(&arena, config, &cfg);
	if (missing_field(env)) {
		bsk_jni_arena_release(&arena);
		return 0;
	}
	bsk_status status = bsk_account_add(engine_of(handle), &cfg, &id, &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
	return (jlong)id;
}

#define ID_CALL(name, call)                                                \
	JNIEXPORT void JNICALL JNI_FN(name)(JNIEnv * env, jclass cls,      \
					    jlong handle, jlong id)        \
	{                                                                  \
		(void)cls;                                                 \
		bsk_error err;                                             \
		memset(&err, 0, sizeof(err));                              \
		bsk_jni_check(env,                                         \
			      call(engine_of(handle), (uint64_t)id, &err), \
			      &err);                                       \
	}

ID_CALL(accountRemove, bsk_account_remove)
ID_CALL(accountSetDefault, bsk_account_set_default)
ID_CALL(accountRegister, bsk_account_register)
ID_CALL(accountUnregister, bsk_account_unregister)
ID_CALL(callHangup, bsk_call_hangup)
ID_CALL(callSetActive, bsk_call_set_active)
ID_CALL(callRequestKeyframe, bsk_call_request_keyframe)
ID_CALL(callRestartIce, bsk_call_restart_ice)
ID_CALL(callRecordStop, bsk_call_record_stop)

JNIEXPORT void JNICALL JNI_FN(accountSetCredentials)(JNIEnv *env, jclass cls,
						     jlong handle, jlong id,
						     jbyteArray user,
						     jbyteArray password)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status = bsk_account_set_credentials(
		engine_of(handle), (uint64_t)id,
		bsk_jni_bytes(&arena, user, NULL),
		bsk_jni_bytes(&arena, password, NULL), &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
}

JNIEXPORT void JNICALL JNI_FN(accountSetContactParams)(JNIEnv *env, jclass cls,
						       jlong handle, jlong id,
						       jobjectArray names,
						       jobjectArray values,
						       jboolean reregister)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	size_t count = 0;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	const bsk_contact_param *params =
		contact_params(&arena, names, values, &count);
	bsk_status status =
		bsk_account_set_contact_params(engine_of(handle), (uint64_t)id,
					       params, count, reregister, &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
}

JNIEXPORT jint JNICALL JNI_FN(accountRegistrationState)(JNIEnv *env, jclass cls,
							jlong handle, jlong id)
{
	(void)env;
	(void)cls;
	bsk_registration_state state = BSK_REG_NONE;
	bsk_account_get_registration_state(engine_of(handle), (uint64_t)id,
					   &state);
	return (jint)state;
}

JNIEXPORT jlongArray JNICALL JNI_FN(accountList)(JNIEnv *env, jclass cls,
						 jlong handle)
{
	(void)cls;
	bsk_engine *engine = engine_of(handle);
	size_t count = bsk_account_list(engine, NULL, NULL, 0);
	bsk_account_id *ids = calloc(count + 1, sizeof(*ids));
	bsk_registration_state *states = calloc(count + 1, sizeof(*states));
	jlongArray result = NULL;
	if (ids && states) {
		size_t written = bsk_account_list(engine, ids, states, count);
		if (written > count)
			written = count;
		result = (*env)->NewLongArray(env, (jsize)(written * 2));
		for (size_t i = 0; result && i < written; i++) {
			jlong pair[2] = { (jlong)ids[i], (jlong)states[i] };
			(*env)->SetLongArrayRegion(env, result, (jsize)(i * 2),
						   2, pair);
		}
	}
	free(ids);
	free(states);
	return result;
}

JNIEXPORT jlong JNICALL JNI_FN(callMake)(JNIEnv *env, jclass cls, jlong handle,
					 jlong account, jbyteArray destination,
					 jboolean audio, jboolean video)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	bsk_call_id id = 0;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status =
		bsk_call_make_media(engine_of(handle), (uint64_t)account,
				    bsk_jni_bytes(&arena, destination, NULL),
				    audio, video, &id, &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
	return (jlong)id;
}

#define ID_TWO_BOOLS(name, call)                                             \
	JNIEXPORT void JNICALL JNI_FN(name)(JNIEnv * env, jclass cls,        \
					    jlong handle, jlong id,          \
					    jboolean first, jboolean second) \
	{                                                                    \
		(void)cls;                                                   \
		bsk_error err;                                               \
		memset(&err, 0, sizeof(err));                                \
		bsk_jni_check(env,                                           \
			      call(engine_of(handle), (uint64_t)id, first,   \
				   second, &err),                            \
			      &err);                                         \
	}

ID_TWO_BOOLS(callAnswer, bsk_call_answer_media)
ID_TWO_BOOLS(callProgress, bsk_call_progress_media)

#define ID_BOOL(name, call)                                                 \
	JNIEXPORT void JNICALL JNI_FN(name)(JNIEnv * env, jclass cls,       \
					    jlong handle, jlong id,         \
					    jboolean value)                 \
	{                                                                   \
		(void)cls;                                                  \
		bsk_error err;                                              \
		memset(&err, 0, sizeof(err));                               \
		bsk_jni_check(                                              \
			env,                                                \
			call(engine_of(handle), (uint64_t)id, value, &err), \
			&err);                                              \
	}

ID_BOOL(callHold, bsk_call_hold)
ID_BOOL(callSetMicrophoneMuted, bsk_call_set_microphone_muted)

JNIEXPORT void JNICALL JNI_FN(callReject)(JNIEnv *env, jclass cls, jlong handle,
					  jlong id, jint code,
					  jbyteArray reason)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status =
		bsk_call_reject(engine_of(handle), (uint64_t)id, (uint16_t)code,
				bsk_jni_bytes(&arena, reason, NULL), &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
}

JNIEXPORT void JNICALL JNI_FN(callSendDtmf)(JNIEnv *env, jclass cls,
					    jlong handle, jlong id,
					    jbyteArray digits, jint duration_ms,
					    jint gap_ms)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status = bsk_call_send_dtmf(
		engine_of(handle), (uint64_t)id,
		bsk_jni_bytes(&arena, digits, NULL), (uint32_t)duration_ms,
		(uint32_t)gap_ms, &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
}

#define ID_INT(name, call, type)                                              \
	JNIEXPORT void JNICALL JNI_FN(name)(                                  \
		JNIEnv * env, jclass cls, jlong handle, jlong id, jint value) \
	{                                                                     \
		(void)cls;                                                    \
		bsk_error err;                                                \
		memset(&err, 0, sizeof(err));                                 \
		bsk_jni_check(env,                                            \
			      call(engine_of(handle), (uint64_t)id,           \
				   (type)value, &err),                        \
			      &err);                                          \
	}

ID_INT(callSetAudioDirection, bsk_call_set_audio_direction, bsk_media_direction)
ID_INT(callSetVideoDirection, bsk_call_set_video_direction, bsk_media_direction)
ID_INT(callSetVideoMaxBitrate, bsk_call_set_video_max_bitrate, uint32_t)

#define ID_STRING(name, call)                                          \
	JNIEXPORT void JNICALL JNI_FN(name)(JNIEnv * env, jclass cls,  \
					    jlong handle, jlong id,    \
					    jbyteArray text)           \
	{                                                              \
		(void)cls;                                             \
		struct bsk_jni_arena arena;                            \
		bsk_error err;                                         \
		memset(&err, 0, sizeof(err));                          \
		bsk_jni_arena_init(&arena, env);                       \
		bsk_status status =                                    \
			call(engine_of(handle), (uint64_t)id,          \
			     bsk_jni_bytes(&arena, text, NULL), &err); \
		bsk_jni_arena_release(&arena);                         \
		bsk_jni_check(env, status, &err);                      \
	}

ID_STRING(callSetCamera, bsk_call_set_camera)
ID_STRING(callRecordStart, bsk_call_record_start)
ID_STRING(callTransfer, bsk_call_transfer)

JNIEXPORT void JNICALL JNI_FN(callTransferAttended)(JNIEnv *env, jclass cls,
						    jlong handle, jlong id,
						    jlong target)
{
	(void)cls;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_check(env,
		      bsk_call_transfer_attended(engine_of(handle),
						 (uint64_t)id, (uint64_t)target,
						 &err),
		      &err);
}

JNIEXPORT jobjectArray JNICALL JNI_FN(callInfo)(JNIEnv *env, jclass cls,
						jlong handle, jlong id,
						jlongArray out)
{
	(void)cls;
	bsk_call_info info;
	memset(&info, 0, sizeof(info));
	bsk_status status =
		bsk_call_get_info(engine_of(handle), (uint64_t)id, &info);
	if (!bsk_jni_check(env, status, NULL))
		return NULL;
	jlong n[BSK_JNI_CALL_INFO_LONGS];
	jobjectArray s = (*env)->NewObjectArray(env, BSK_JNI_CALL_INFO_STRINGS,
						bsk_jni_string_class(), NULL);
	if (!s)
		return NULL;
	bsk_jni_pack_call_info(env, &info, n, s, 0);
	(*env)->SetLongArrayRegion(env, out, 0, BSK_JNI_CALL_INFO_LONGS, n);
	return s;
}

JNIEXPORT jobjectArray JNICALL JNI_FN(callStatistics)(JNIEnv *env, jclass cls,
						      jlong handle, jlong id,
						      jlongArray out)
{
	(void)cls;
	bsk_call_statistics stats;
	memset(&stats, 0, sizeof(stats));
	bsk_status status = bsk_call_get_statistics(engine_of(handle),
						    (uint64_t)id, &stats);
	if (!bsk_jni_check(env, status, NULL))
		return NULL;
	jlong n[BSK_JNI_STATISTICS_LONGS];
	jobjectArray s = (*env)->NewObjectArray(env, BSK_JNI_STATISTICS_STRINGS,
						bsk_jni_string_class(), NULL);
	if (!s)
		return NULL;
	bsk_jni_pack_statistics(env, &stats, n, s, 0);
	(*env)->SetLongArrayRegion(env, out, 0, BSK_JNI_STATISTICS_LONGS, n);
	return s;
}

JNIEXPORT jstring JNICALL JNI_FN(callHeader)(JNIEnv *env, jclass cls,
					     jlong handle, jlong id,
					     jbyteArray name)
{
	(void)cls;
	struct bsk_jni_arena arena;
	char value[1024];
	bsk_jni_arena_init(&arena, env);
	bsk_status status = bsk_call_get_header(
		engine_of(handle), (uint64_t)id,
		bsk_jni_bytes(&arena, name, NULL), value, sizeof(value));
	bsk_jni_arena_release(&arena);
	if (status == BSK_ERR_NOT_FOUND) {
		bsk_call_info info;
		status = bsk_call_get_info(engine_of(handle), (uint64_t)id,
					   &info);
		bsk_jni_check(env, status, NULL);
		return NULL;
	}
	if (!bsk_jni_check(env, status, NULL))
		return NULL;
	return bsk_jni_string_n(env, value, strnlen(value, sizeof(value)));
}

JNIEXPORT jlongArray JNICALL JNI_FN(callList)(JNIEnv *env, jclass cls,
					      jlong handle)
{
	(void)cls;
	bsk_engine *engine = engine_of(handle);
	size_t count = bsk_call_list(engine, NULL, 0);
	bsk_call_id *ids = calloc(count + 1, sizeof(*ids));
	if (!ids)
		return NULL;
	size_t written = bsk_call_list(engine, ids, count);
	if (written > count)
		written = count;
	jlongArray result = (*env)->NewLongArray(env, (jsize)written);
	if (result)
		(*env)->SetLongArrayRegion(env, result, 0, (jsize)written,
					   (const jlong *)ids);
	free(ids);
	return result;
}

JNIEXPORT jlong JNICALL JNI_FN(messageSend)(JNIEnv *env, jclass cls,
					    jlong handle, jlong account,
					    jbyteArray peer, jbyteArray text)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	uint64_t id = 0;
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status =
		bsk_message_send(engine_of(handle), (uint64_t)account,
				 bsk_jni_bytes(&arena, peer, NULL),
				 bsk_jni_bytes(&arena, text, NULL), &id, &err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
	return (jlong)id;
}

JNIEXPORT jstring JNICALL JNI_FN(videoDevices)(JNIEnv *env, jclass cls,
					       jlong handle)
{
	(void)cls;
	bsk_engine *engine = engine_of(handle);
	size_t needed = bsk_video_list_devices(engine, NULL, 0);
	char *buf = calloc(1, needed + 1);
	if (!buf)
		return NULL;
	bsk_video_list_devices(engine, buf, needed + 1);
	jstring result = bsk_jni_string(env, buf);
	free(buf);
	return result;
}
