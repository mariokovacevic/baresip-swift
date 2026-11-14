#ifndef BSK_FRAME_H
#define BSK_FRAME_H

#include <stdbool.h>
#include <stdint.h>
#include "baresip_kit.h"

bool bsk_frame_strides_ok(const bsk_video_frame *frame);
bool bsk_crop_valid(int32_t width, int32_t height, int32_t left, int32_t top,
		    int32_t right, int32_t bottom);
uint64_t bsk_yuv420_extent(uint32_t stride, uint32_t slice, bool planar,
			   uint32_t left, uint32_t top, uint32_t width,
			   uint32_t height);
uint64_t bsk_yuv420_packed_size(uint32_t width, uint32_t height);

#endif
