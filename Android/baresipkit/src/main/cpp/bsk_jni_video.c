#include <errno.h>
#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "baresip_kit.h"
#ifdef __ANDROID__
#include "baresip_kit_android.h"
#endif
#include "bsk_jni.h"

#define JNI_FN(name) \
	Java_io_github_mariokovacevic_baresipkit_internal_Native_##name

struct bsk_jni_sink {
	jobject box;
};

static jclass native_class;
static jmethodID on_frame;
static jmethodID on_frame_size;
#ifdef __ANDROID__
static jmethodID camera_start;
static jmethodID camera_stop;
static jmethodID camera_switch;
#endif

static bool load_methods(JNIEnv *env)
{
	if (native_class)
		return true;
	jclass local = (*env)->FindClass(
		env, "io/github/mariokovacevic/baresipkit/internal/Native");
	if (!local)
		return false;
	native_class = (*env)->NewGlobalRef(env, local);
	on_frame = (*env)->GetStaticMethodID(
		env, native_class, "onFrame",
		"(Ljava/lang/Object;IIILjava/nio/ByteBuffer;Ljava/nio/"
		"ByteBuffer;Ljava/nio/ByteBuffer;IIIJI)V");
	on_frame_size = (*env)->GetStaticMethodID(
		env, native_class, "onFrameSize", "(Ljava/lang/Object;II)V");
#ifdef __ANDROID__
	camera_start = (*env)->GetStaticMethodID(
		env, native_class, "cameraStart", "(JLjava/lang/String;III)I");
	camera_stop = (*env)->GetStaticMethodID(env, native_class, "cameraStop",
						"(J)V");
	camera_switch = (*env)->GetStaticMethodID(
		env, native_class, "cameraSwitch", "(JLjava/lang/String;)I");
#endif
	return on_frame && on_frame_size;
}

static size_t plane_size(const bsk_video_frame *frame, int plane)
{
	uint32_t rows = plane == 0 ? frame->height : (frame->height + 1) / 2;
	if (frame->format == BSK_PIX_BGRA)
		rows = plane == 0 ? frame->height : 0;
	if (frame->format == BSK_PIX_NV12 && plane == 2)
		rows = 0;
	return (size_t)frame->strides[plane] * rows;
}

static void sink_frame(bsk_engine *engine, bsk_call_id call, bool local,
		       const bsk_video_frame *frame, void *user)
{
	struct bsk_jni_sink *sink = user;
	JNIEnv *env = bsk_jni_env();
	jobject planes[3] = { NULL, NULL, NULL };
	(void)engine;
	(void)call;
	(void)local;

	if (!env || !sink || !frame || !load_methods(env))
		return;
	if ((*env)->PushLocalFrame(env, 8) != 0)
		return;
	for (int i = 0; i < 3; i++) {
		size_t size = plane_size(frame, i);
		if (frame->planes[i] && size)
			planes[i] = (*env)->NewDirectByteBuffer(
				env, (void *)frame->planes[i], (jlong)size);
	}
	(*env)->CallStaticVoidMethod(
		env, native_class, on_frame, sink->box, (jint)frame->format,
		(jint)frame->width, (jint)frame->height, planes[0], planes[1],
		planes[2], (jint)frame->strides[0], (jint)frame->strides[1],
		(jint)frame->strides[2], (jlong)frame->timestamp_us,
		(jint)frame->rotation_degrees);
	if ((*env)->ExceptionCheck(env))
		(*env)->ExceptionClear(env);
	(*env)->PopLocalFrame(env, NULL);
}

static void sink_size(bsk_engine *engine, bsk_call_id call, bool local,
		      uint32_t width, uint32_t height, void *user)
{
	struct bsk_jni_sink *sink = user;
	JNIEnv *env = bsk_jni_env();
	(void)engine;
	(void)call;
	(void)local;

	if (!env || !sink || !load_methods(env))
		return;
	(*env)->CallStaticVoidMethod(env, native_class, on_frame_size,
				     sink->box, (jint)width, (jint)height);
	if ((*env)->ExceptionCheck(env))
		(*env)->ExceptionClear(env);
}

static bsk_engine *engine_of(jlong handle)
{
	struct bsk_jni_engine *owner =
		(struct bsk_jni_engine *)(intptr_t)handle;
	return owner ? owner->engine : NULL;
}

static bsk_video_sink make_sink(jlong ptr)
{
	bsk_video_sink sink;
	memset(&sink, 0, sizeof(sink));
	if (ptr) {
		sink.on_frame = sink_frame;
		sink.on_size = sink_size;
		sink.user = (void *)(intptr_t)ptr;
	}
	return sink;
}

JNIEXPORT jlong JNICALL JNI_FN(sinkCreate)(JNIEnv *env, jclass cls, jobject box)
{
	(void)cls;
	if (!load_methods(env))
		return 0;
	struct bsk_jni_sink *sink = calloc(1, sizeof(*sink));
	if (!sink)
		return 0;
	sink->box = (*env)->NewGlobalRef(env, box);
	return (jlong)(intptr_t)sink;
}

JNIEXPORT void JNICALL JNI_FN(sinkRelease)(JNIEnv *env, jclass cls, jlong ptr)
{
	(void)cls;
	struct bsk_jni_sink *sink = (struct bsk_jni_sink *)(intptr_t)ptr;
	if (!sink)
		return;
	(*env)->DeleteGlobalRef(env, sink->box);
	free(sink);
}

JNIEXPORT void JNICALL JNI_FN(callSetVideoSink)(JNIEnv *env, jclass cls,
						jlong handle, jlong call,
						jboolean local, jlong ptr)
{
	(void)cls;
	bsk_error err;
	bsk_video_sink sink = make_sink(ptr);
	memset(&err, 0, sizeof(err));
	bsk_jni_check(env,
		      bsk_call_set_video_sink(engine_of(handle), (uint64_t)call,
					      local, ptr ? &sink : NULL, &err),
		      &err);
}

JNIEXPORT void JNICALL JNI_FN(videoPreviewStart)(JNIEnv *env, jclass cls,
						 jlong handle,
						 jbyteArray device, jlong ptr)
{
	(void)cls;
	struct bsk_jni_arena arena;
	bsk_error err;
	bsk_video_sink sink = make_sink(ptr);
	memset(&err, 0, sizeof(err));
	bsk_jni_arena_init(&arena, env);
	bsk_status status = bsk_video_preview_start(
		engine_of(handle), bsk_jni_bytes(&arena, device, NULL), &sink,
		&err);
	bsk_jni_arena_release(&arena);
	bsk_jni_check(env, status, &err);
}

JNIEXPORT void JNICALL JNI_FN(videoPreviewStop)(JNIEnv *env, jclass cls,
						jlong handle)
{
	(void)cls;
	bsk_error err;
	memset(&err, 0, sizeof(err));
	bsk_jni_check(env, bsk_video_preview_stop(engine_of(handle), &err),
		      &err);
}

#ifdef __ANDROID__

static int host_start(void *source, const char *device, uint32_t width,
		      uint32_t height, uint32_t fps, void *user)
{
	JNIEnv *env = bsk_jni_env();
	(void)user;
	if (!env || !load_methods(env))
		return ENODEV;
	jstring name = bsk_jni_string(env, device);
	jint result = (*env)->CallStaticIntMethod(
		env, native_class, camera_start, (jlong)(intptr_t)source, name,
		(jint)width, (jint)height, (jint)fps);
	(*env)->DeleteLocalRef(env, name);
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
		return ENODEV;
	}
	return result;
}

static void host_stop(void *source, void *user)
{
	JNIEnv *env = bsk_jni_env();
	(void)user;
	if (!env || !load_methods(env))
		return;
	(*env)->CallStaticVoidMethod(env, native_class, camera_stop,
				     (jlong)(intptr_t)source);
	if ((*env)->ExceptionCheck(env))
		(*env)->ExceptionClear(env);
}

static int host_switch(void *source, const char *device, void *user)
{
	JNIEnv *env = bsk_jni_env();
	(void)user;
	if (!env || !load_methods(env))
		return ENODEV;
	jstring name = bsk_jni_string(env, device);
	jint result =
		(*env)->CallStaticIntMethod(env, native_class, camera_switch,
					    (jlong)(intptr_t)source, name);
	(*env)->DeleteLocalRef(env, name);
	if ((*env)->ExceptionCheck(env)) {
		(*env)->ExceptionClear(env);
		return ENODEV;
	}
	return result;
}

JNIEXPORT void JNICALL JNI_FN(cameraInstallHost)(JNIEnv *env, jclass cls,
						 jboolean install)
{
	(void)cls;
	bsk_camera_host host;
	memset(&host, 0, sizeof(host));
	if (install && load_methods(env)) {
		host.start = host_start;
		host.stop = host_stop;
		host.switch_device = host_switch;
	}
	bsk_camera_set_host(install ? &host : NULL);
}

static uint8_t sample(const uint8_t *plane, size_t stride, size_t pixel,
		      size_t x, size_t y)
{
	return plane[y * stride + x * pixel];
}

static void source_point(int rotation, size_t w, size_t h, size_t x, size_t y,
			 size_t *sx, size_t *sy)
{
	switch (rotation) {
	case 90:
		*sx = y;
		*sy = h - 1 - x;
		break;
	case 180:
		*sx = w - 1 - x;
		*sy = h - 1 - y;
		break;
	case 270:
		*sx = w - 1 - y;
		*sy = x;
		break;
	default:
		*sx = x;
		*sy = y;
		break;
	}
}

static uint8_t *rotated_i420(const uint8_t *py, const uint8_t *pu,
			     const uint8_t *pv, size_t y_stride,
			     size_t uv_stride, size_t uv_pixel, size_t w,
			     size_t h, int rotation, size_t *out_w,
			     size_t *out_h)
{
	const bool swap = rotation == 90 || rotation == 270;
	const size_t ow = swap ? h : w, oh = swap ? w : h;
	const size_t cw = (ow + 1) / 2, ch = (oh + 1) / 2;
	const size_t sw = (w + 1) / 2, sh = (h + 1) / 2;
	uint8_t *copy = malloc(ow * oh + 2 * cw * ch);
	size_t sx, sy;

	if (!copy)
		return NULL;
	uint8_t *cu = copy + ow * oh;
	uint8_t *cv = cu + cw * ch;
	for (size_t y = 0; y < oh; y++) {
		for (size_t x = 0; x < ow; x++) {
			source_point(rotation, w, h, x, y, &sx, &sy);
			copy[y * ow + x] = sample(py, y_stride, 1, sx, sy);
		}
	}
	for (size_t y = 0; y < ch; y++) {
		for (size_t x = 0; x < cw; x++) {
			source_point(rotation, sw, sh, x, y, &sx, &sy);
			cu[y * cw + x] =
				sample(pu, uv_stride, uv_pixel, sx, sy);
			cv[y * cw + x] =
				sample(pv, uv_stride, uv_pixel, sx, sy);
		}
	}
	*out_w = ow;
	*out_h = oh;
	return copy;
}

static bool plane_fits(JNIEnv *env, jobject buffer, size_t rows, size_t stride,
		       size_t row_bytes)
{
	jlong capacity = (*env)->GetDirectBufferCapacity(env, buffer);
	if (capacity < 0 || !rows || !row_bytes || stride < row_bytes)
		return false;
	return (uint64_t)(rows - 1) * stride + row_bytes <= (uint64_t)capacity;
}

static bool camera_planes_fit(JNIEnv *env, jobject y, jobject u, jobject v,
			      jint width, jint height, jint y_stride,
			      jint uv_stride, jint uv_pixel_stride)
{
	if (width <= 0 || height <= 0 || y_stride <= 0 || uv_stride <= 0 ||
	    uv_pixel_stride < 1)
		return false;
	const size_t cw = ((size_t)width + 1) / 2;
	const size_t ch = ((size_t)height + 1) / 2;
	const size_t chroma_row = (cw - 1) * (size_t)uv_pixel_stride + 1;
	return plane_fits(env, y, (size_t)height, (size_t)y_stride,
			  (size_t)width) &&
	       plane_fits(env, u, ch, (size_t)uv_stride, chroma_row) &&
	       plane_fits(env, v, ch, (size_t)uv_stride, chroma_row);
}

JNIEXPORT jboolean JNICALL JNI_FN(cameraPush)(
	JNIEnv *env, jclass cls, jlong source, jint width, jint height,
	jobject y, jobject u, jobject v, jint y_stride, jint uv_stride,
	jint uv_pixel_stride, jlong timestamp_us, jint rotation)
{
	(void)cls;
	const uint8_t *py = (*env)->GetDirectBufferAddress(env, y);
	const uint8_t *pu = (*env)->GetDirectBufferAddress(env, u);
	const uint8_t *pv = (*env)->GetDirectBufferAddress(env, v);
	bsk_video_frame frame;
	uint8_t *copy = NULL;
	jboolean delivered;

	if (!py || !pu || !pv ||
	    !camera_planes_fit(env, y, u, v, width, height, y_stride, uv_stride,
			       uv_pixel_stride))
		return JNI_FALSE;

	memset(&frame, 0, sizeof(frame));
	frame.width = (uint32_t)width;
	frame.height = (uint32_t)height;
	frame.timestamp_us = (uint64_t)timestamp_us;
	frame.planes[0] = py;
	frame.strides[0] = (uint32_t)y_stride;

	if (rotation == 0 && uv_pixel_stride == 1) {
		frame.format = BSK_PIX_I420;
		frame.planes[1] = pu;
		frame.planes[2] = pv;
		frame.strides[1] = (uint32_t)uv_stride;
		frame.strides[2] = (uint32_t)uv_stride;
	} else if (rotation == 0 && uv_pixel_stride == 2 && pv == pu + 1) {
		frame.format = BSK_PIX_NV12;
		frame.planes[1] = pu;
		frame.strides[1] = (uint32_t)uv_stride;
	} else {
		size_t w, h;
		copy = rotated_i420(py, pu, pv, (size_t)y_stride,
				    (size_t)uv_stride, (size_t)uv_pixel_stride,
				    (size_t)width, (size_t)height,
				    ((rotation % 360) + 360) % 360, &w, &h);
		if (!copy)
			return JNI_FALSE;
		const size_t cw = (w + 1) / 2, ch = (h + 1) / 2;
		frame.format = BSK_PIX_I420;
		frame.width = (uint32_t)w;
		frame.height = (uint32_t)h;
		frame.planes[0] = copy;
		frame.planes[1] = copy + w * h;
		frame.planes[2] = copy + w * h + cw * ch;
		frame.strides[0] = (uint32_t)w;
		frame.strides[1] = (uint32_t)cw;
		frame.strides[2] = (uint32_t)cw;
	}

	delivered = bsk_camera_push((void *)(intptr_t)source, &frame);
	free(copy);
	return delivered;
}

#endif
