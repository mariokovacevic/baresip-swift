package io.github.mariokovacevic.baresipkit.video

internal object VideoGeometry {
    fun quad(
        frameWidth: Int,
        frameHeight: Int,
        rotationDegrees: Int,
        viewWidth: Int,
        viewHeight: Int,
        fill: Boolean,
        mirrored: Boolean,
    ): FloatArray {
        val quarter = ((rotationDegrees % 360 + 360) % 360) / 90
        val swapped = quarter % 2 == 1
        val shownWidth = (if (swapped) frameHeight else frameWidth).coerceAtLeast(1).toFloat()
        val shownHeight = (if (swapped) frameWidth else frameHeight).coerceAtLeast(1).toFloat()
        val frameAspect = shownWidth / shownHeight
        val viewAspect = viewWidth.coerceAtLeast(1).toFloat() / viewHeight.coerceAtLeast(1)
        var sx = 1f
        var sy = 1f
        if ((frameAspect > viewAspect) == fill) {
            sx = frameAspect / viewAspect
        } else {
            sy = viewAspect / frameAspect
        }
        if (mirrored) sx = -sx
        val corners =
            listOf(
                floatArrayOf(-sx, -sy),
                floatArrayOf(sx, -sy),
                floatArrayOf(-sx, sy),
                floatArrayOf(sx, sy),
            )
        val textures =
            listOf(
                floatArrayOf(0f, 1f),
                floatArrayOf(1f, 1f),
                floatArrayOf(0f, 0f),
                floatArrayOf(1f, 0f),
            )
        val order = intArrayOf(0, 1, 3, 2)
        val result = FloatArray(16)
        for (i in 0 until 4) {
            val rotated = textures[order[(order.indexOf(i) + quarter) % 4]]
            result[i * 4] = corners[i][0]
            result[i * 4 + 1] = corners[i][1]
            result[i * 4 + 2] = rotated[0]
            result[i * 4 + 3] = rotated[1]
        }
        return result
    }
}
