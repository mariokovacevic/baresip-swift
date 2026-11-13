package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Hearing
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import io.github.mariokovacevic.baresipkit.compose.BaresipCallVideo
import io.github.mariokovacevic.baresipkit.video.BaresipVideoView
import io.github.mariokovacevic.baresipkit.zvono.model.CallModel
import io.github.mariokovacevic.baresipkit.zvono.model.CallPreviewFeed
import io.github.mariokovacevic.baresipkit.zvono.model.CallRow
import io.github.mariokovacevic.baresipkit.zvono.model.CallText
import io.github.mariokovacevic.baresipkit.zvono.model.answer
import io.github.mariokovacevic.baresipkit.zvono.model.doorFor
import io.github.mariokovacevic.baresipkit.zvono.model.openRingingDoor
import io.github.mariokovacevic.baresipkit.zvono.model.phoneCall
import io.github.mariokovacevic.baresipkit.zvono.model.preview
import io.github.mariokovacevic.baresipkit.zvono.model.reject
import io.github.mariokovacevic.baresipkit.zvono.model.ringingDoor

@Composable
fun IncomingCallScreen(
    model: CallModel,
    row: CallRow,
) {
    BackHandler {}
    rememberTick()
    val door = model.doorFor(row.remoteUri)
    val title = door?.title ?: row.title
    val hasVideo = row.hasVideo || model.incomingEarlyVideo
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.callBackground)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .testTag("incoming"),
    ) {
        Box(Modifier.weight(1f).fillMaxWidth().background(Palette.picture)) {
            val call = model.phoneCall(row.id)
            val feed = model.previewFeed?.takeIf { it.call == row.id }
            when {
                model.previewing && model.previewVideo && feed != null ->
                    FeedVideo(feed, Modifier.fillMaxSize().semantics { contentDescription = "Caller's video" }) { view ->
                        model.snapshots.register(view, feed.call)
                    }
                model.previewing && model.previewVideo && call != null ->
                    BaresipCallVideo(call, Modifier.fillMaxSize().semantics { contentDescription = "Caller's video" }) { view ->
                        model.snapshots.register(view, call.id)
                    }
                model.previewing && model.previewVideo && model.demoMode -> DemoDoorView(Modifier.fillMaxSize())
                else ->
                    Column(
                        Modifier.fillMaxWidth().padding(top = 170.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        if (hasVideo || door != null) {
                            Icon(Icons.Outlined.Person, contentDescription = null, tint = Palette.pictureMark, modifier = Modifier.size(140.dp))
                        } else {
                            Avatar(row.initials, size = 120.dp)
                        }
                        if (!model.previewing) PreviewButton(model, hasVideo)
                    }
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.overlay)
                    .statusBarsPadding()
                    .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatusDot(Palette.brass)
                    Text(
                        "RINGING ${CallText.duration(row.startedAt.elapsedNow())}",
                        style = Type.footnoteStrong.copy(letterSpacing = 0.8.sp),
                        color = Palette.brass,
                    )
                }
                Spacer(Modifier.height(6.dp))
                Text(title, style = Type.display(40.sp), color = Palette.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (door == null) Text(row.remoteUri, style = Type.footnote, color = Palette.secondary, maxLines = 1)
            }
            if (model.previewing) {
                val what = if (model.previewVideo) "see" else "hear"
                Text(
                    "You $what ${if (door == null) "the caller" else "the door"}. They cannot see or hear you.",
                    style = Type.footnote,
                    color = Palette.text,
                    modifier =
                        Modifier
                            .align(Alignment.BottomStart)
                            .padding(16.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Palette.overlay)
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                )
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.barLine))
        Column(
            Modifier
                .fillMaxWidth()
                .background(Palette.bar)
                .navigationBarsPadding()
                .padding(start = 24.dp, end = 24.dp, top = 22.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.SpaceBetween) {
                RingButton("Decline", Icons.Filled.Close, 68.dp, Palette.alert, Palette.hangUp, "incoming.reject") { model.act { reject() } }
                if (model.ringingDoor != null) {
                    RingButton("Open door", Icons.Filled.Key, 96.dp, Palette.onBrass, Palette.brass, "incoming.openDoor") { model.act { openRingingDoor() } }
                }
                RingButton("Answer", Icons.Filled.Call, 68.dp, Palette.background, Palette.text, "incoming.answer") { model.act { answer() } }
            }
            Text(
                if (model.ringingDoor != null) "Open door answers, sends the door code and hangs up." else "Your microphone and camera turn on only when you answer.",
                style = Type.footnote,
                color = Palette.secondary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun PreviewButton(
    model: CallModel,
    hasVideo: Boolean,
) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(Palette.text)
            .clickable(role = Role.Button) { model.act { preview() } }
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .testTag("incoming.preview"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(if (hasVideo) Icons.Outlined.Visibility else Icons.Filled.Hearing, contentDescription = null, tint = Palette.background, modifier = Modifier.size(18.dp))
        Text(if (hasVideo) "See who is there" else "Listen first", style = Type.subheadlineStrong, color = Palette.background)
    }
}

@Composable
private fun RingButton(
    title: String,
    icon: ImageVector,
    size: Dp,
    foreground: Color,
    background: Color,
    tag: String,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .widthIn(min = 84.dp)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = title }
            .testTag(tag),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.size(size).clip(CircleShape).background(background), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = foreground, modifier = Modifier.size(size * 0.4f))
        }
        Text(
            title,
            style = if (size > 80.dp) Type.subheadlineStrong else Type.subheadlineMedium,
            color = if (size > 80.dp) Palette.brass else Palette.text,
        )
    }
}

@Composable
fun DemoDoorView(modifier: Modifier = Modifier) {
    Box(
        modifier.background(
            androidx.compose.ui.graphics.Brush.verticalGradient(
                listOf(Color(0xFF3A4656), Color(0xFF263140), Color(0xFF151C25)),
            ),
        ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Outlined.Person, contentDescription = "Picture from the door camera", tint = Color(0xFF8A97A8), modifier = Modifier.size(180.dp))
        Text(
            "Door camera",
            style = Type.caption,
            color = Palette.secondary,
            modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
        )
    }
}

@Composable
fun FeedVideo(
    feed: CallPreviewFeed,
    modifier: Modifier = Modifier,
    onView: (BaresipVideoView) -> Unit = {},
) {
    val context = LocalContext.current
    val view = remember(context) { BaresipVideoView(context).also(onView) }
    view.scaleMode = BaresipVideoView.ScaleMode.FIT
    DisposableEffect(feed) {
        feed.setDisplay(view.renderer)
        onDispose {
            feed.removeDisplay(view.renderer)
            view.flush()
        }
    }
    AndroidView(factory = { view }, modifier = modifier)
}
