#include <jni.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#include "baresip_kit.h"
#include "bsk_jni.h"

#ifdef __ANDROID__
#define ATTACH_ENV(env) (env)
#else
#define ATTACH_ENV(env) ((void **)(env))
#endif

static JavaVM *jvm;
static pthread_key_t detach_key;
static jclass native_class;
static jclass string_class;
static jclass bytes_class;
static jmethodID string_init;
static jmethodID on_event;
static jmethodID on_log;
static jmethodID make_error;
static jobject utf8;

static void detach_thread(void *value)
{
	(void)value;
	(*jvm)->DetachCurrentThread(jvm);
}

JNIEnv *bsk_jni_env(void)
{
	JNIEnv *env = NULL;
	if ((*jvm)->GetEnv(jvm, (void **)&env, JNI_VERSION_1_6) == JNI_OK)
		return env;
	if ((*jvm)->AttachCurrentThreadAsDaemon(jvm, ATTACH_ENV(&env), NULL) !=
	    JNI_OK)
		return NULL;
	pthread_setspecific(detach_key, env);
	return env;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
{
	(void)reserved;
	JNIEnv *env;
	jvm = vm;
	if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6) != JNI_OK)
		return JNI_ERR;
	if (pthread_key_create(&detach_key, detach_thread) != 0)
		return JNI_ERR;

	jclass local = (*env)->FindClass(
		env, "io/github/mariokovacevic/baresipkit/internal/Native");
	if (!local)
		return JNI_ERR;
	native_class = (*env)->NewGlobalRef(env, local);
	on_event = (*env)->GetStaticMethodID(
		env, native_class, "onEvent",
		"(Ljava/lang/Object;IJJ[J[Ljava/lang/String;[B)V");
	on_log = (*env)->GetStaticMethodID(env, native_class, "onLog",
					   "(Ljava/lang/Object;II[B)V");
	make_error = (*env)->GetStaticMethodID(
		env, native_class, "error",
		"(IIILjava/lang/String;Ljava/lang/String;I)Ljava/lang/"
		"Throwable;");

	local = (*env)->FindClass(env, "java/lang/String");
	string_class = (*env)->NewGlobalRef(env, local);
	string_init = (*env)->GetMethodID(env, string_class, "<init>",
					  "([BLjava/nio/charset/Charset;)V");
	local = (*env)->FindClass(env, "[B");
	bytes_class = (*env)->NewGlobalRef(env, local);

	jclass charsets =
		(*env)->FindClass(env, "java/nio/charset/StandardCharsets");
	jfieldID field = (*env)->GetStaticFieldID(env, charsets, "UTF_8",
						  "Ljava/nio/charset/Charset;");
	utf8 = (*env)->NewGlobalRef(
		env, (*env)->GetStaticObjectField(env, charsets, field));

	if (!on_event || !on_log || !make_error || !string_init || !utf8)
		return JNI_ERR;
	return JNI_VERSION_1_6;
}

jstring bsk_jni_string_n(JNIEnv *env, const char *text, size_t len)
{
	if (!text)
		return NULL;
	jbyteArray bytes = (*env)->NewByteArray(env, (jsize)len);
	if (!bytes)
		return NULL;
	(*env)->SetByteArrayRegion(env, bytes, 0, (jsize)len,
				   (const jbyte *)text);
	jstring result =
		(*env)->NewObject(env, string_class, string_init, bytes, utf8);
	(*env)->DeleteLocalRef(env, bytes);
	return result;
}

jstring bsk_jni_string(JNIEnv *env, const char *text)
{
	return text ? bsk_jni_string_n(env, text, strnlen(text, 65536)) : NULL;
}

static jstring array_string(JNIEnv *env, const char *text, size_t capacity)
{
	return bsk_jni_string_n(env, text, strnlen(text, capacity));
}

#define FIXED_STRING(env, field) array_string(env, field, sizeof(field))

void bsk_jni_throw(JNIEnv *env, bsk_status status, const bsk_error *err)
{
	bsk_error empty;
	memset(&empty, 0, sizeof(empty));
	if (!err)
		err = &empty;
	jstring reason = FIXED_STRING(env, err->sip_reason);
	jstring message = FIXED_STRING(env, err->message);
	int code = err->status != BSK_OK ? (int)err->status : (int)status;
	jobject error = (*env)->CallStaticObjectMethod(
		env, native_class, make_error, code, (jint)err->sys_errno,
		(jint)err->sip_status, reason, message, 0);
	if (error)
		(*env)->Throw(env, error);
}

bool bsk_jni_check(JNIEnv *env, bsk_status status, const bsk_error *err)
{
	if (status == BSK_OK)
		return true;
	if (!(*env)->ExceptionCheck(env))
		bsk_jni_throw(env, status, err);
	return false;
}

void bsk_jni_arena_init(struct bsk_jni_arena *arena, JNIEnv *env)
{
	memset(arena, 0, sizeof(*arena));
	arena->env = env;
}

const char *bsk_jni_bytes(struct bsk_jni_arena *arena, jbyteArray array,
			  size_t *out_len)
{
	if (out_len)
		*out_len = 0;
	if (!array || arena->pinned_count >= BSK_JNI_ARENA_PINS)
		return NULL;
	JNIEnv *env = arena->env;
	jbyte *bytes = (*env)->GetByteArrayElements(env, array, NULL);
	if (!bytes)
		return NULL;
	arena->pinned[arena->pinned_count].array = array;
	arena->pinned[arena->pinned_count].bytes = bytes;
	arena->pinned_count++;
	if (out_len)
		*out_len = (size_t)(*env)->GetArrayLength(env, array);
	return (const char *)bytes;
}

void *bsk_jni_alloc(struct bsk_jni_arena *arena, size_t size)
{
	if (arena->block_count >= BSK_JNI_ARENA_BLOCKS)
		return NULL;
	void *block = calloc(1, size ? size : 1);
	if (block)
		arena->blocks[arena->block_count++] = block;
	return block;
}

const char *const *bsk_jni_strings(struct bsk_jni_arena *arena,
				   jobjectArray array, size_t *out_count)
{
	*out_count = 0;
	if (!array)
		return NULL;
	JNIEnv *env = arena->env;
	jsize count = (*env)->GetArrayLength(env, array);
	const char **list = bsk_jni_alloc(arena, sizeof(char *) * (count + 1));
	if (!list)
		return NULL;
	for (jsize i = 0; i < count; i++) {
		jbyteArray item = (*env)->GetObjectArrayElement(env, array, i);
		list[i] = bsk_jni_bytes(arena, item, NULL);
	}
	*out_count = (size_t)count;
	return list;
}

void bsk_jni_arena_release(struct bsk_jni_arena *arena)
{
	JNIEnv *env = arena->env;
	for (size_t i = 0; i < arena->pinned_count; i++) {
		(*env)->ReleaseByteArrayElements(env, arena->pinned[i].array,
						 arena->pinned[i].bytes,
						 JNI_ABORT);
	}
	for (size_t i = 0; i < arena->block_count; i++)
		free(arena->blocks[i]);
	arena->pinned_count = 0;
	arena->block_count = 0;
}

static void put_error(jlong *n, const bsk_error *err,
		      bsk_call_end_reason reason)
{
	n[0] = err->status;
	n[1] = err->sys_errno;
	n[2] = err->sip_status;
	n[3] = reason;
}

void bsk_jni_pack_call_info(JNIEnv *env, const bsk_call_info *info, jlong *n,
			    jobjectArray s, int first_string)
{
	n[0] = (jlong)info->id;
	n[1] = (jlong)info->account;
	n[2] = info->state;
	n[3] = info->outgoing;
	n[4] = info->has_video;
	n[5] = info->audio_dir;
	n[6] = info->video_dir;
	n[7] = info->setup_ms;
	n[8] = info->duration_s;
	n[9] = info->microphone_muted;
	n[10] = (jlong)info->replaces;
	jstring values[] = {
		FIXED_STRING(env, info->sip_call_id),
		FIXED_STRING(env, info->remote_uri),
		FIXED_STRING(env, info->remote_display_name),
		FIXED_STRING(env, info->audio_codec),
		FIXED_STRING(env, info->video_codec),
	};
	for (int i = 0; i < 5; i++) {
		(*env)->SetObjectArrayElement(env, s, first_string + i,
					      values[i]);
		(*env)->DeleteLocalRef(env, values[i]);
	}
}

static int pack_stream(const bsk_stream_statistics *st, jlong *n, int i)
{
	n[i++] = st->tx_packets;
	n[i++] = st->rx_packets;
	n[i++] = (jlong)st->tx_bytes;
	n[i++] = (jlong)st->rx_bytes;
	n[i++] = st->rx_lost;
	n[i++] = st->rx_fraction_lost_permille;
	n[i++] = st->rx_jitter_ms;
	n[i++] = st->rtt_ms;
	n[i++] = st->tx_bitrate_bps;
	n[i++] = st->rx_bitrate_bps;
	n[i++] = st->jitter_buffer_delay_ms;
	n[i++] = st->secure;
	return i;
}

void bsk_jni_pack_statistics(JNIEnv *env, const bsk_call_statistics *stats,
			     jlong *n, jobjectArray s, int first_string)
{
	double mos = stats->mos_estimate;
	int64_t mos_bits;
	memcpy(&mos_bits, &mos, sizeof(mos_bits));
	int i = 0;
	n[i++] = (jlong)stats->id;
	n[i++] = stats->ice_state;
	n[i++] = stats->local_candidate;
	n[i++] = stats->remote_candidate;
	n[i++] = mos_bits;
	n[i++] = stats->video_target_bitrate_bps;
	i = pack_stream(&stats->audio, n, i);
	pack_stream(&stats->video, n, i);
	jstring local = FIXED_STRING(env, stats->local_address);
	jstring remote = FIXED_STRING(env, stats->remote_address);
	(*env)->SetObjectArrayElement(env, s, first_string, local);
	(*env)->SetObjectArrayElement(env, s, first_string + 1, remote);
	(*env)->DeleteLocalRef(env, local);
	(*env)->DeleteLocalRef(env, remote);
}

static void set_string(JNIEnv *env, jobjectArray s, int index, jstring value)
{
	(*env)->SetObjectArrayElement(env, s, index, value);
	(*env)->DeleteLocalRef(env, value);
}

static void deliver_event(bsk_engine *engine, const bsk_event *event,
			  void *user)
{
	(void)engine;
	struct bsk_jni_engine *owner = user;
	JNIEnv *env = bsk_jni_env();
	if (!env || !owner)
		return;
	if ((*env)->PushLocalFrame(env, 32) != 0)
		return;

	jlong n[BSK_JNI_EVENT_LONGS];
	memset(n, 0, sizeof(n));
	jobjectArray s = (*env)->NewObjectArray(env, BSK_JNI_EVENT_STRINGS,
						string_class, NULL);
	jbyteArray body = NULL;
	bsk_error no_error;
	memset(&no_error, 0, sizeof(no_error));
	const bsk_error *err = &no_error;
	bsk_call_end_reason reason = BSK_END_NORMAL;
	jlong *x = n + BSK_JNI_EVENT_FIRST_LONG;

	switch (event->type) {
	case BSK_EVENT_ENGINE_STATE:
		err = &event->u.engine.error;
		x[0] = event->u.engine.state;
		break;
	case BSK_EVENT_REGISTRATION:
		err = &event->u.registration.error;
		x[0] = event->u.registration.state;
		x[1] = event->u.registration.expires;
		break;
	case BSK_EVENT_CALL_STATE:
		err = &event->u.call_state.error;
		reason = event->u.call_state.end_reason;
		x[0] = event->u.call_state.state;
		break;
	case BSK_EVENT_CALL_INCOMING:
		bsk_jni_pack_call_info(env, &event->u.call_incoming.info, x, s,
				       BSK_JNI_EVENT_FIRST_STRING);
		x[BSK_JNI_CALL_INFO_LONGS] = event->u.call_incoming.early_video;
		break;
	case BSK_EVENT_CALL_MEDIA:
		x[0] = event->u.media.event;
		x[1] = event->u.media.audio_dir;
		x[2] = event->u.media.video_dir;
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.media.detail));
		break;
	case BSK_EVENT_CALL_DTMF:
		x[0] = (unsigned char)event->u.dtmf.digit;
		x[1] = event->u.dtmf.end;
		x[2] = event->u.dtmf.via_sip_info;
		break;
	case BSK_EVENT_CALL_TRANSFER:
		x[0] = event->u.transfer.failed;
		x[1] = event->u.transfer.sip_status;
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.transfer.target_uri));
		break;
	case BSK_EVENT_CALL_STATISTICS:
		bsk_jni_pack_statistics(env, &event->u.statistics.stats, x, s,
					BSK_JNI_EVENT_FIRST_STRING);
		break;
	case BSK_EVENT_ICE:
		x[0] = event->u.ice.state;
		x[1] = event->u.ice.local_candidate;
		x[2] = event->u.ice.remote_candidate;
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.ice.local_address));
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING + 1,
			   FIXED_STRING(env, event->u.ice.remote_address));
		break;
	case BSK_EVENT_NETWORK:
		x[0] = event->u.network.transports_reset;
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.network.local_address));
		break;
	case BSK_EVENT_AUDIO:
		err = &event->u.audio.error;
		x[0] = event->u.audio.input_running;
		x[1] = event->u.audio.output_running;
		break;
	case BSK_EVENT_DIAGNOSTIC:
		x[0] = event->u.diagnostic.level;
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.diagnostic.message));
		break;
	case BSK_EVENT_MESSAGE:
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING,
			   FIXED_STRING(env, event->u.message.from));
		set_string(env, s, BSK_JNI_EVENT_FIRST_STRING + 1,
			   FIXED_STRING(env, event->u.message.content_type));
		body = (*env)->NewByteArray(env,
					    (jsize)event->u.message.body_len);
		if (body && event->u.message.body_len)
			(*env)->SetByteArrayRegion(
				env, body, 0, (jsize)event->u.message.body_len,
				(const jbyte *)event->u.message.body);
		break;
	case BSK_EVENT_MESSAGE_STATUS:
		err = &event->u.message_status.error;
		x[0] = (jlong)event->u.message_status.message_id;
		x[1] = event->u.message_status.delivered;
		x[2] = event->u.message_status.sip_status;
		break;
	default: (*env)->PopLocalFrame(env, NULL); return;
	}

	put_error(n, err, reason);
	set_string(env, s, 0, FIXED_STRING(env, err->sip_reason));
	set_string(env, s, 1, FIXED_STRING(env, err->message));
	jlongArray longs = (*env)->NewLongArray(env, BSK_JNI_EVENT_LONGS);
	if (longs && s) {
		(*env)->SetLongArrayRegion(env, longs, 0, BSK_JNI_EVENT_LONGS,
					   n);
		(*env)->CallStaticVoidMethod(
			env, native_class, on_event, owner->owner,
			(jint)event->type, (jlong)event->account,
			(jlong)event->call, longs, s, body);
	}
	if ((*env)->ExceptionCheck(env))
		(*env)->ExceptionClear(env);
	(*env)->PopLocalFrame(env, NULL);
}

static void deliver_log(bsk_log_level level, bsk_log_domain domain,
			const char *line, size_t len, void *user)
{
	struct bsk_jni_engine *owner = user;
	JNIEnv *env = bsk_jni_env();
	if (!env || !owner || !line)
		return;
	jbyteArray bytes = (*env)->NewByteArray(env, (jsize)len);
	if (!bytes)
		return;
	(*env)->SetByteArrayRegion(env, bytes, 0, (jsize)len,
				   (const jbyte *)line);
	(*env)->CallStaticVoidMethod(env, native_class, on_log, owner->owner,
				     (jint)level, (jint)domain, bytes);
	if ((*env)->ExceptionCheck(env))
		(*env)->ExceptionClear(env);
	(*env)->DeleteLocalRef(env, bytes);
}

void bsk_jni_install_callbacks(struct bsk_jni_engine *owner)
{
	bsk_engine_set_event_handler(owner->engine, deliver_event, owner);
	bsk_engine_set_log_handler(owner->engine, deliver_log, owner);
}

void bsk_jni_remove_callbacks(struct bsk_jni_engine *owner)
{
	bsk_engine_set_event_handler(owner->engine, NULL, NULL);
	bsk_engine_set_log_handler(owner->engine, NULL, NULL);
}

jclass bsk_jni_bytes_class(void)
{
	return bytes_class;
}

jclass bsk_jni_string_class(void)
{
	return string_class;
}
