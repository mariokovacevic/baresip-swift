#include "bsk_frame.h"


static bool plane_ok(const bsk_video_frame *frame, int plane, uint32_t row)
{
	return frame->planes[plane] && frame->strides[plane] >= row &&
	       frame->strides[plane] <= UINT16_MAX;
}


bool bsk_frame_strides_ok(const bsk_video_frame *frame)
{
	const uint32_t cw = frame->width / 2 + frame->width % 2;

	if (!frame->width || !frame->height ||
	    !plane_ok(frame, 0, frame->width))
		return false;
	if (frame->format == BSK_PIX_NV12)
		return plane_ok(frame, 1, 2 * cw);
	if (frame->format == BSK_PIX_I420)
		return plane_ok(frame, 1, cw) && plane_ok(frame, 2, cw);

	return false;
}


bool bsk_crop_valid(int32_t width, int32_t height, int32_t left, int32_t top,
		    int32_t right, int32_t bottom)
{
	return width > 0 && height > 0 && left >= 0 && top >= 0 &&
	       right >= left && bottom >= top && right < width &&
	       bottom < height;
}


uint64_t bsk_yuv420_extent(uint32_t stride, uint32_t slice, bool planar,
			   uint32_t left, uint32_t top, uint32_t width,
			   uint32_t height)
{
	const uint64_t s = stride, rows = slice;
	const uint64_t luma = s * rows;
	const uint64_t cw = ((uint64_t)width + 1) / 2;
	const uint64_t ch = ((uint64_t)height + 1) / 2;

	if (!width || !height ||
	    ((uint64_t)top + height - 1) * s + left + width > luma)
		return 0;

	if (planar)
		return luma + (s / 2) * (rows / 2) +
		       (top / 2 + ch - 1) * (s / 2) + left / 2 + cw;

	return luma + (top / 2 + ch - 1) * s + (left & ~1u) + 2 * cw;
}


uint64_t bsk_yuv420_packed_size(uint32_t width, uint32_t height)
{
	const uint64_t cw = ((uint64_t)width + 1) / 2;
	const uint64_t ch = ((uint64_t)height + 1) / 2;

	return (uint64_t)width * height + 2 * cw * ch;
}
