package io.github.mariokovacevic.baresipkit.compose

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import io.github.mariokovacevic.baresipkit.BaresipCallID
import io.github.mariokovacevic.baresipkit.BaresipEngine
import io.github.mariokovacevic.baresipkit.video.BaresipVideoView
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Which video of a call [BaresipCallVideo] shows. */
enum class BaresipVideoSource {
    /** The other side's video. */
    REMOTE,

    /** Your camera, as it is sent. */
    LOCAL,
}

/**
 * Shows a call's remote video or your own camera. The renderer is attached while the composable
 * is shown and detached when it leaves the composition.
 *
 * @param onView Called once with the view, for example to keep it for snapshots.
 */
@Composable
fun BaresipCallVideo(
    engine: BaresipEngine,
    call: BaresipCallID,
    modifier: Modifier = Modifier,
    source: BaresipVideoSource = BaresipVideoSource.REMOTE,
    scaleMode: BaresipVideoView.ScaleMode = BaresipVideoView.ScaleMode.FILL,
    mirrored: Boolean = source == BaresipVideoSource.LOCAL,
    onView: (BaresipVideoView) -> Unit = {},
) {
    val context = LocalContext.current
    val view =
        remember(context) {
            BaresipVideoView(context).also(onView)
        }
    view.scaleMode = scaleMode
    view.isMirrored = mirrored
    LaunchedEffect(engine, call, source) {
        val local = source == BaresipVideoSource.LOCAL
        val key = VideoClaims.Key(engine, call, local)
        val claim = VideoClaims.claim(key)
        try {
            runCatching { engine.setVideoRenderer(call, view.renderer, local) }
            awaitCancellation()
        } finally {
            withContext(NonCancellable) {
                if (VideoClaims.release(key, claim)) {
                    runCatching { engine.setVideoRenderer(call, null, local) }
                }
                view.flush()
            }
        }
    }
    AndroidView(factory = { view }, modifier = modifier)
}

/**
 * Shows the camera preview outside a call, for example before placing a video call.
 *
 * @param device The camera, `front` or `back`.
 */
@Composable
fun BaresipCameraPreview(
    engine: BaresipEngine,
    modifier: Modifier = Modifier,
    device: String? = null,
    mirrored: Boolean = device != "back",
) {
    val context = LocalContext.current
    val view = remember(context) { BaresipVideoView(context) }
    view.isMirrored = mirrored
    LaunchedEffect(engine, device) {
        val key = VideoClaims.Key(engine, null, true)
        val claim = VideoClaims.claim(key)
        try {
            runCatching { engine.startVideoPreview(device, view.renderer) }
            awaitCancellation()
        } finally {
            withContext(NonCancellable) {
                if (VideoClaims.release(key, claim)) {
                    runCatching { engine.stopVideoPreview() }
                }
            }
        }
    }
    AndroidView(factory = { view }, modifier = modifier)
}

/**
 * Shows a phone call's remote video or the camera image it sends. The camera image is mirrored
 * while the front camera is used.
 */
@Composable
fun BaresipCallVideo(
    call: BaresipPhoneCall,
    modifier: Modifier = Modifier,
    source: BaresipVideoSource = BaresipVideoSource.REMOTE,
    scaleMode: BaresipVideoView.ScaleMode? = null,
    onView: (BaresipVideoView) -> Unit = {},
) = BaresipCallVideo(
    engine = call.engine,
    call = call.id,
    modifier = modifier,
    source = source,
    scaleMode =
        scaleMode ?: if (source == BaresipVideoSource.LOCAL) BaresipVideoView.ScaleMode.FILL else BaresipVideoView.ScaleMode.FIT,
    mirrored = source == BaresipVideoSource.LOCAL && call.camera.isMirroredInPreview,
    onView = onView,
)

/**
 * The small picture of your own camera that call screens show in a corner while the camera is
 * sent. It shows nothing while [BaresipPhoneCall.isSendingVideo] is `false`, mirrors the front
 * camera, and switches between the front and back camera when tapped.
 */
@Composable
fun BaresipSelfView(
    call: BaresipPhoneCall,
    modifier: Modifier = Modifier,
    size: DpSize = DpSize(100.dp, 140.dp),
    cornerRadius: Dp = 12.dp,
    switchesCameraOnTap: Boolean = true,
) {
    if (!call.isSendingVideo) return
    val scope = rememberCoroutineScope()
    val shape = RoundedCornerShape(cornerRadius)
    val tappable =
        if (switchesCameraOnTap) {
            Modifier.clickable(role = Role.Button, onClickLabel = "Switch camera") {
                scope.launch { runCatching { call.switchCamera() } }
            }
        } else {
            Modifier
        }
    BaresipCallVideo(
        call = call,
        source = BaresipVideoSource.LOCAL,
        modifier =
            modifier
                .size(size)
                .shadow(6.dp, shape)
                .clip(shape)
                .background(Color.Black)
                .border(1.dp, Color.White.copy(alpha = 0.35f), shape)
                .semantics { contentDescription = "Your camera" }
                .then(tappable),
    )
}
