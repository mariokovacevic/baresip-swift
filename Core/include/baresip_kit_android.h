#ifndef BARESIP_KIT_ANDROID_H
#define BARESIP_KIT_ANDROID_H

#include "baresip_kit.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct bsk_camera_host {
	int (*start)(void *source, const char *device, uint32_t width,
		     uint32_t height, uint32_t fps, void *user);
	void (*stop)(void *source, void *user);
	int (*switch_device)(void *source, const char *device, void *user);
	void *user;
} bsk_camera_host;

BSK_EXPORT void bsk_camera_set_host(const bsk_camera_host *host);
BSK_EXPORT bool bsk_camera_push(void *source, const bsk_video_frame *frame);

#ifdef __cplusplus
}
#endif

#endif
