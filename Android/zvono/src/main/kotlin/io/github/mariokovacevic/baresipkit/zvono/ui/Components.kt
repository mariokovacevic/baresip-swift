package io.github.mariokovacevic.baresipkit.zvono.ui

import android.graphics.Bitmap
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.zvono.R
import kotlinx.coroutines.delay

@Composable
fun rememberTick(): Int {
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            tick++
        }
    }
    return tick
}

@Composable
fun Card(
    modifier: Modifier = Modifier,
    radius: Dp = 20.dp,
    highlighted: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(radius)
    Column(
        modifier =
            modifier
                .fillMaxWidth()
                .clip(shape)
                .background(Palette.surface)
                .border(1.dp, if (highlighted) Palette.raisedLine else Palette.line, shape),
        content = content,
    )
}

@Composable
fun RowDivider() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.line))
}

@Composable
fun SectionTitle(
    title: String,
    modifier: Modifier = Modifier,
) {
    Text(
        title.uppercase(),
        style = Type.footnoteStrong.copy(letterSpacing = 0.8.sp),
        color = Palette.secondary,
        modifier = modifier.padding(horizontal = 4.dp).semantics { heading() },
    )
}

@Composable
fun TitledSection(
    title: String,
    note: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionTitle(title)
        content()
        if (note != null) Note(note)
    }
}

@Composable
fun Note(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(text, style = Type.footnote, color = Palette.secondary, modifier = modifier.padding(horizontal = 4.dp))
}

@Composable
fun ScreenTitle(title: String) {
    Text(
        title,
        style = Type.display(36.sp),
        color = Palette.text,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp).semantics { heading() },
    )
}

@Composable
fun ToggleRow(
    title: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    detail: String? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .heightIn(min = if (detail == null) 52.dp else 62.dp)
                .clickable(role = Role.Switch) { onChange(!checked) }
                .padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Type.body, color = Palette.text)
            if (detail != null) Text(detail, style = Type.footnote, color = Palette.secondary)
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors =
                SwitchDefaults.colors(
                    checkedThumbColor = Palette.onBrass,
                    checkedTrackColor = Palette.brass,
                    checkedBorderColor = Palette.brass,
                    uncheckedThumbColor = Palette.secondary,
                    uncheckedTrackColor = Palette.raised,
                    uncheckedBorderColor = Palette.field,
                ),
        )
    }
}

@Composable
fun LinkRow(
    title: String,
    value: String? = null,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = Palette.secondary, modifier = Modifier.size(22.dp))
        Text(title, style = Type.body, color = Palette.text, modifier = Modifier.weight(1f, fill = false))
        Spacer(Modifier.weight(1f))
        if (value != null) {
            Text(value, style = Type.subheadline, color = Palette.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 180.dp))
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = Palette.secondary)
    }
}

@Composable
fun ValueRow(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth().heightIn(min = 46.dp).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(title, style = Type.subheadline, color = Palette.text)
        Spacer(Modifier.weight(1f))
        Text(value, style = Type.subheadline, color = Palette.secondary, textAlign = androidx.compose.ui.text.style.TextAlign.End)
    }
}

@Composable
fun CardButton(
    title: String,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Text(
        title,
        style = Type.subheadlineMedium,
        color = if (destructive) Palette.alert else Palette.info,
        modifier =
            modifier
                .fillMaxWidth()
                .heightIn(min = 52.dp)
                .alpha(if (enabled) 1f else 0.45f)
                .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 16.dp),
    )
}

enum class ButtonKind { BRASS, LIGHT, RAISED, SOFT_BRASS, DANGER }

@Composable
fun FilledButton(
    title: String,
    kind: ButtonKind,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    height: Dp = 52.dp,
    radius: Dp = 14.dp,
    expands: Boolean = true,
    enabled: Boolean = true,
    textStyle: TextStyle = Type.bodyStrong,
    onClick: () -> Unit,
) {
    val (foreground, background, border) =
        when (kind) {
            ButtonKind.BRASS -> Triple(Palette.onBrass, Palette.brass, Color.Transparent)
            ButtonKind.LIGHT -> Triple(Palette.background, Palette.text, Color.Transparent)
            ButtonKind.RAISED -> Triple(Palette.text, Palette.raised, Palette.raisedLine)
            ButtonKind.SOFT_BRASS -> Triple(Palette.brass, Palette.brassSoft, Palette.brassLine)
            ButtonKind.DANGER -> Triple(Palette.alert, Palette.failed, Palette.failedLine)
        }
    val shape = RoundedCornerShape(radius)
    Row(
        modifier =
            modifier
                .then(if (expands) Modifier.fillMaxWidth() else Modifier)
                .heightIn(min = height)
                .alpha(if (enabled) 1f else 0.45f)
                .clip(shape)
                .background(background)
                .border(BorderStroke(1.dp, border), shape)
                .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
                .padding(horizontal = 18.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = foreground, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(title, style = textStyle, color = foreground, maxLines = 1)
    }
}

@Composable
fun CallControl(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    size: Dp = 56.dp,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier.clickable(role = Role.Button, onClick = onClick).padding(vertical = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            Modifier.size(size).clip(CircleShape).background(if (active) Palette.text else Palette.raised),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (active) Palette.background else Palette.text, modifier = Modifier.size(size * 0.42f))
        }
        Text(title, style = Type.footnoteMedium, color = Palette.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
fun FilterChip(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Text(
        title,
        style = if (selected) Type.subheadlineStrong else Type.subheadlineMedium,
        color = if (selected) Palette.background else Palette.text,
        modifier =
            Modifier
                .clip(CircleShape)
                .background(if (selected) Palette.text else Palette.surface)
                .border(1.dp, if (selected) Color.Transparent else Palette.field, CircleShape)
                .clickable(role = Role.Tab, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

@Composable
fun RoundIcon(
    icon: ImageVector,
    description: String,
    modifier: Modifier = Modifier,
    size: Dp = 44.dp,
    onClick: () -> Unit,
) {
    Box(
        modifier =
            modifier
                .size(size)
                .clip(CircleShape)
                .background(Palette.surface)
                .border(1.dp, Palette.line, CircleShape)
                .clickable(role = Role.Button, onClick = onClick)
                .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Palette.text, modifier = Modifier.size(size * 0.45f))
    }
}

@Composable
fun Avatar(
    initials: String,
    size: Dp = 44.dp,
    corner: Dp? = null,
) {
    val shape = RoundedCornerShape(corner ?: (size / 2))
    Box(
        Modifier
            .size(size)
            .clip(shape)
            .background(Palette.raised)
            .border(1.dp, Palette.field, shape),
        contentAlignment = Alignment.Center,
    ) {
        Text(initials, style = Type.display((size.value * 0.42f).sp), color = Palette.text)
    }
}

@Composable
fun CameraPicture(
    image: Bitmap?,
    modifier: Modifier = Modifier,
    caption: String? = null,
    markSize: Dp = 56.dp,
) {
    Box(modifier.background(Palette.picture), contentAlignment = Alignment.Center) {
        if (image != null) {
            Image(
                image.asImageBitmap(),
                contentDescription = "Picture from the door camera",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Outlined.Person, contentDescription = null, tint = Palette.pictureMark, modifier = Modifier.size(markSize))
                if (caption != null) Text(caption, style = Type.caption, color = Palette.secondary)
            }
        }
    }
}

@Composable
fun StatusDot(
    color: Color,
    size: Dp = 8.dp,
) {
    Box(Modifier.size(size).clip(CircleShape).background(color))
}

@Composable
fun LogoMark(size: Dp = 56.dp) {
    Box(
        Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.29f))
            .background(Palette.brass)
            .semantics { contentDescription = "Zvono" },
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(R.drawable.ic_logo), contentDescription = null, tint = Palette.onBrass, modifier = Modifier.size(size * 0.62f))
    }
}

@Composable
fun BackBar(
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(48.dp)
                .clip(CircleShape)
                .clickable(role = Role.Button, onClick = onBack)
                .semantics { contentDescription = "Back" },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = Palette.info)
        }
        Spacer(Modifier.weight(1f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically, content = actions)
        Spacer(Modifier.width(12.dp))
    }
}

@Composable
fun TextAction(
    title: String,
    modifier: Modifier = Modifier,
    color: Color = Palette.info,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Text(
        title,
        style = Type.subheadlineStrong,
        color = color,
        modifier =
            modifier
                .alpha(if (enabled) 1f else 0.45f)
                .clip(RoundedCornerShape(8.dp))
                .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
                .padding(horizontal = 10.dp, vertical = 12.dp),
    )
}
