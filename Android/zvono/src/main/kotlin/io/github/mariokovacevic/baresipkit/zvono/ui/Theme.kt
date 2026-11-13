package io.github.mariokovacevic.baresipkit.zvono.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import io.github.mariokovacevic.baresipkit.zvono.R

object Palette {
    val background = Color(0xFF0F141B)
    val callBackground = Color(0xFF0B0F14)
    val bar = Color(0xFF121821)
    val barLine = Color(0xFF232D3A)
    val surface = Color(0xFF18202B)
    val line = Color(0xFF263140)
    val field = Color(0xFF2E3A4B)
    val raised = Color(0xFF222C3A)
    val raisedLine = Color(0xFF3D4B5F)
    val picture = Color(0xFF1C2633)
    val pictureMark = Color(0xFF43536A)
    val text = Color(0xFFF2F4F7)
    val secondary = Color(0xFFA9B4C2)
    val brass = Color(0xFFF0B24A)
    val onBrass = Color(0xFF1A1203)
    val brassSoft = Color(0xFF2A2213)
    val brassLine = Color(0xFF5A4520)
    val info = Color(0xFF6FB6F2)
    val alert = Color(0xFFFFB8AD)
    val hangUp = Color(0xFF4A2320)
    val failed = Color(0xFF2A1615)
    val failedLine = Color(0xFF5A2A26)
    val overlay = Color(0xC70B0F14)
    val caption = Color(0x9E000000)
}

object Type {
    val display =
        FontFamily(
            Font(R.font.barlow_semi_condensed_semibold, FontWeight.SemiBold),
            Font(R.font.barlow_semi_condensed_medium, FontWeight.Medium),
        )

    fun display(size: TextUnit) = TextStyle(fontFamily = display, fontWeight = FontWeight.SemiBold, fontSize = size, lineHeight = size * 1.1f)

    fun displayMedium(size: TextUnit) = TextStyle(fontFamily = display, fontWeight = FontWeight.Medium, fontSize = size, lineHeight = size * 1.1f)

    val body = TextStyle(fontSize = 16.sp, lineHeight = 22.sp)
    val bodyStrong = body.copy(fontWeight = FontWeight.SemiBold)
    val subheadline = TextStyle(fontSize = 15.sp, lineHeight = 20.sp)
    val subheadlineStrong = subheadline.copy(fontWeight = FontWeight.SemiBold)
    val subheadlineMedium = subheadline.copy(fontWeight = FontWeight.Medium)
    val footnote = TextStyle(fontSize = 13.sp, lineHeight = 18.sp)
    val footnoteStrong = footnote.copy(fontWeight = FontWeight.SemiBold)
    val footnoteMedium = footnote.copy(fontWeight = FontWeight.Medium)
    val caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp)
    val captionStrong = caption.copy(fontWeight = FontWeight.SemiBold)
    val small = TextStyle(fontSize = 11.sp, lineHeight = 14.sp)
    val title = TextStyle(fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.SemiBold)
}

@Composable
fun ZvonoTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme =
            darkColorScheme(
                primary = Palette.brass,
                onPrimary = Palette.onBrass,
                secondary = Palette.info,
                background = Palette.background,
                onBackground = Palette.text,
                surface = Palette.surface,
                onSurface = Palette.text,
                surfaceVariant = Palette.raised,
                onSurfaceVariant = Palette.secondary,
                surfaceContainer = Palette.bar,
                surfaceContainerHigh = Palette.raised,
                surfaceContainerLow = Palette.surface,
                outline = Palette.field,
                outlineVariant = Palette.line,
                error = Palette.alert,
            ),
        content = content,
    )
}
