package io.github.mariokovacevic.baresipkit.zvono.model

object ProximityRule {
    fun watches(
        connected: Boolean,
        audioOnly: Boolean,
        userChoseOutput: Boolean,
        current: OutputKind?,
    ): Boolean = connected && audioOnly && !userChoseOutput && current != OutputKind.BLUETOOTH && current != OutputKind.HEADSET

    fun route(
        near: Boolean,
        audioOnly: Boolean,
        userChoseOutput: Boolean,
        current: OutputKind?,
        available: Set<OutputKind>,
    ): OutputKind? {
        if (!audioOnly || userChoseOutput) return null
        if (current == OutputKind.BLUETOOTH || current == OutputKind.HEADSET) return null
        val wanted = if (near) OutputKind.PHONE else OutputKind.SPEAKER
        if (current == wanted || wanted !in available) return null
        return wanted
    }
}
