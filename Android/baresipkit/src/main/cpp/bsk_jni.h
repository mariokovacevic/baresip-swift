#ifndef BSK_JNI_H
#define BSK_JNI_H

#include <jni.h>
#include <stdbool.h>
#include <stddef.h>

#include "baresip_kit.h"

#define BSK_JNI_EVENT_LONGS 40
#define BSK_JNI_EVENT_FIRST_LONG 4
#define BSK_JNI_EVENT_STRINGS 8
#define BSK_JNI_EVENT_FIRST_STRING 2
#define BSK_JNI_CALL_INFO_LONGS 10
#define BSK_JNI_CALL_INFO_STRINGS 5
#define BSK_JNI_STATISTICS_LONGS 30
#define BSK_JNI_STATISTICS_STRINGS 2

#define BSK_JNI_ARENA_PINS 256
#define BSK_JNI_ARENA_BLOCKS 16

struct bsk_jni_engine {
	bsk_engine *engine;
	jobject owner;
};

struct bsk_jni_pin {
	jbyteArray array;
	jbyte *bytes;
};

struct bsk_jni_arena {
	JNIEnv *env;
	struct bsk_jni_pin pinned[BSK_JNI_ARENA_PINS];
	size_t pinned_count;
	void *blocks[BSK_JNI_ARENA_BLOCKS];
	size_t block_count;
};

JNIEnv *bsk_jni_env(void);
jstring bsk_jni_string(JNIEnv *env, const char *text);
jstring bsk_jni_string_n(JNIEnv *env, const char *text, size_t len);
jclass bsk_jni_bytes_class(void);
jclass bsk_jni_string_class(void);

void bsk_jni_throw(JNIEnv *env, bsk_status status, const bsk_error *err);
bool bsk_jni_check(JNIEnv *env, bsk_status status, const bsk_error *err);

void bsk_jni_arena_init(struct bsk_jni_arena *arena, JNIEnv *env);
const char *bsk_jni_bytes(struct bsk_jni_arena *arena, jbyteArray array,
			  size_t *out_len);
const char *const *bsk_jni_strings(struct bsk_jni_arena *arena,
				   jobjectArray array, size_t *out_count);
void *bsk_jni_alloc(struct bsk_jni_arena *arena, size_t size);
void bsk_jni_arena_release(struct bsk_jni_arena *arena);

void bsk_jni_pack_call_info(JNIEnv *env, const bsk_call_info *info, jlong *n,
			    jobjectArray s, int first_string);
void bsk_jni_pack_statistics(JNIEnv *env, const bsk_call_statistics *stats,
			     jlong *n, jobjectArray s, int first_string);

void bsk_jni_install_callbacks(struct bsk_jni_engine *owner);
void bsk_jni_remove_callbacks(struct bsk_jni_engine *owner);

#endif
