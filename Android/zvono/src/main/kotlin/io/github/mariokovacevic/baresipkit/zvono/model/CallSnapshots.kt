package io.github.mariokovacevic.baresipkit.zvono.model

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.video.BaresipVideoView
import java.io.File
import java.lang.ref.WeakReference
import java.util.UUID

class CallSnapshots(
    private val directory: File,
) {
    private val views = HashMap<BaresipCallID, WeakReference<BaresipVideoView>>()
    private val cache = HashMap<String, Bitmap>()

    fun register(
        view: BaresipVideoView,
        call: BaresipCallID,
    ) {
        views[call] = WeakReference(view)
    }

    fun finish(call: BaresipCallID): String? {
        val view = views.remove(call)?.get() ?: return null
        val picture = runCatching { view.snapshot() }.getOrNull() ?: return null
        return save(picture)
    }

    fun save(picture: Bitmap): String? {
        val scale = THUMBNAIL_WIDTH.toFloat() / picture.width.coerceAtLeast(1)
        val small =
            if (scale < 1) {
                Bitmap.createScaledBitmap(picture, THUMBNAIL_WIDTH, (picture.height * scale).toInt().coerceAtLeast(1), true)
            } else {
                picture
            }
        val name = "${UUID.randomUUID()}.jpg"
        return runCatching {
            directory.mkdirs()
            File(directory, name).outputStream().use { small.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
            cache[name] = small
            name
        }.getOrNull()
    }

    fun image(name: String): Bitmap? = cache[name] ?: runCatching { BitmapFactory.decodeFile(File(directory, name).path) }.getOrNull()?.also { cache[name] = it }

    fun prune(keeping: Set<String>) {
        directory.listFiles()?.filter { it.name !in keeping }?.forEach { it.delete() }
        cache.keys.retainAll(keeping)
    }

    private companion object {
        const val THUMBNAIL_WIDTH = 320
        const val JPEG_QUALITY = 80
    }
}
