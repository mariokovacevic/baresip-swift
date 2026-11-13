package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun PlainTextField(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    style: TextStyle = Type.body,
    keyboardType: KeyboardType = KeyboardType.Text,
    secure: Boolean = false,
    singleLine: Boolean = true,
    alignEnd: Boolean = false,
    imeAction: ImeAction = ImeAction.Default,
    onDone: () -> Unit = {},
    tag: String? = null,
) {
    val align = if (alignEnd) TextAlign.End else TextAlign.Start
    BasicTextField(
        value = value,
        onValueChange = onChange,
        textStyle = style.copy(color = Palette.text, textAlign = align),
        cursorBrush = SolidColor(Palette.brass),
        singleLine = singleLine,
        maxLines = if (singleLine) 1 else 4,
        visualTransformation = if (secure) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions =
            KeyboardOptions(
                keyboardType = if (secure) KeyboardType.Password else keyboardType,
                autoCorrectEnabled = false,
                imeAction = imeAction,
            ),
        keyboardActions = KeyboardActions(onAny = { onDone() }),
        modifier = modifier.then(if (tag != null) Modifier.testTag(tag) else Modifier),
        decorationBox = { inner ->
            Box(contentAlignment = if (alignEnd) Alignment.CenterEnd else Alignment.CenterStart) {
                if (value.isEmpty()) Text(placeholder, style = style.copy(textAlign = align), color = Palette.secondary.copy(alpha = 0.6f), maxLines = 1)
                inner()
            }
        },
    )
}

@Composable
fun StackedField(
    title: String,
    value: String,
    onChange: (String) -> Unit,
    placeholder: String = "",
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    secure: Boolean = false,
    tag: String? = null,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = Type.footnoteMedium, color = Palette.secondary)
        val shape = RoundedCornerShape(12.dp)
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 50.dp)
                .clip(shape)
                .background(Palette.surface)
                .border(1.dp, Palette.field, shape)
                .padding(horizontal = 14.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            PlainTextField(value, onChange, placeholder, Modifier.fillMaxWidth(), keyboardType = keyboardType, secure = secure, tag = tag)
        }
    }
}

@Composable
fun FieldRow(
    title: String,
    value: String,
    onChange: (String) -> Unit,
    placeholder: String = "",
    keyboardType: KeyboardType = KeyboardType.Text,
    secure: Boolean = false,
    tag: String? = null,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.subheadline, color = Palette.text)
        Spacer(Modifier.width(12.dp))
        PlainTextField(
            value,
            onChange,
            placeholder,
            Modifier.weight(1f),
            style = Type.subheadline,
            keyboardType = keyboardType,
            secure = secure,
            alignEnd = true,
            tag = tag,
        )
    }
}

@Composable
fun <T> MenuRow(
    title: String,
    selection: T,
    options: List<T>,
    label: (T) -> String,
    onSelect: (T) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clickable(role = Role.DropdownList) { open = true }
            .padding(start = 16.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.subheadline, color = Palette.text)
        Spacer(Modifier.weight(1f))
        Box {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(label(selection), style = Type.subheadline, color = Palette.secondary)
                Icon(Icons.Filled.ArrowDropDown, contentDescription = null, tint = Palette.secondary)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }, containerColor = Palette.raised) {
                for (option in options) {
                    DropdownMenuItem(
                        text = { Text(label(option), color = Palette.text) },
                        onClick = {
                            open = false
                            onSelect(option)
                        },
                    )
                }
            }
        }
    }
}

@Composable
fun <T> Segments(
    selection: T,
    options: List<T>,
    label: (T) -> String,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier
            .clip(shape)
            .background(Palette.raised)
            .border(1.dp, Palette.field, shape)
            .padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (option in options) {
            val selected = option == selection
            Text(
                label(option),
                style = if (selected) Type.footnoteStrong else Type.footnoteMedium,
                color = if (selected) Palette.background else Palette.text,
                textAlign = TextAlign.Center,
                modifier =
                    Modifier
                        .weight(1f, fill = true)
                        .clip(RoundedCornerShape(8.dp))
                        .background(if (selected) Palette.text else Palette.raised)
                        .clickable(role = Role.RadioButton) { onSelect(option) }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }
    }
}

@Composable
fun <T> SegmentRow(
    title: String,
    selection: T,
    options: List<T>,
    label: (T) -> String,
    onSelect: (T) -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.subheadline, color = Palette.text)
        Spacer(Modifier.width(16.dp))
        Segments(selection, options, label, Modifier.weight(1f), onSelect)
    }
}

@Composable
fun StepperRow(
    title: String,
    value: String,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title, style = Type.subheadline, color = Palette.text)
        Spacer(Modifier.weight(1f))
        Text(value, style = Type.subheadline, color = Palette.secondary)
        StepButton(Icons.Filled.Remove, "Less", onDecrease)
        StepButton(Icons.Filled.Add, "More", onIncrease)
    }
}

@Composable
private fun StepButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(Palette.raised)
            .clickable(role = Role.Button, onClickLabel = description, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = description, tint = Palette.text, modifier = Modifier.size(18.dp))
    }
}

@Composable
fun ConfirmDialog(
    title: String,
    confirm: String,
    message: String? = null,
    destructive: Boolean = true,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.raised,
        title = { Text(title, style = Type.title, color = Palette.text) },
        text = message?.let { { Text(it, style = Type.subheadline, color = Palette.secondary) } },
        confirmButton = {
            TextButton(onClick = {
                onDismiss()
                onConfirm()
            }) { Text(confirm, color = if (destructive) Palette.alert else Palette.info) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Palette.info) } },
    )
}

@Composable
fun ChoiceDialog(
    title: String,
    message: String?,
    choices: List<Pair<String, () -> Unit>>,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.raised,
        title = { Text(title, style = Type.title, color = Palette.text) },
        text = {
            Column {
                if (message != null) Text(message, style = Type.footnote, color = Palette.secondary, modifier = Modifier.padding(bottom = 8.dp))
                for ((label, action) in choices) {
                    val destructive = label.startsWith("Remove")
                    Text(
                        label,
                        style = Type.bodyStrong,
                        color = if (destructive) Palette.alert else Palette.info,
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .clickable {
                                    onDismiss()
                                    action()
                                }.padding(vertical = 12.dp, horizontal = 4.dp),
                    )
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Palette.info) } },
    )
}
