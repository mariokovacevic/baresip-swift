package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.zvono.model.OutputKind
import io.github.mariokovacevic.baresipkit.zvono.model.ProximityRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProximityRuleTest {
    private val builtIn = setOf(OutputKind.PHONE, OutputKind.SPEAKER)

    @Test
    fun heldToTheEarMovesToTheEarpieceAndBackToTheLoudspeaker() {
        assertEquals(OutputKind.PHONE, ProximityRule.route(near = true, audioOnly = true, userChoseOutput = false, current = OutputKind.SPEAKER, available = builtIn))
        assertEquals(OutputKind.SPEAKER, ProximityRule.route(near = false, audioOnly = true, userChoseOutput = false, current = OutputKind.PHONE, available = builtIn))
        assertNull(ProximityRule.route(near = true, audioOnly = true, userChoseOutput = false, current = OutputKind.PHONE, available = builtIn))
        assertNull(ProximityRule.route(near = false, audioOnly = true, userChoseOutput = false, current = OutputKind.SPEAKER, available = builtIn))
    }

    @Test
    fun aChoiceOfTheUserVideoOrAHeadsetStopsTheSwitching() {
        assertNull(ProximityRule.route(near = true, audioOnly = true, userChoseOutput = true, current = OutputKind.SPEAKER, available = builtIn))
        assertNull(ProximityRule.route(near = true, audioOnly = false, userChoseOutput = false, current = OutputKind.SPEAKER, available = builtIn))
        assertNull(ProximityRule.route(near = true, audioOnly = true, userChoseOutput = false, current = OutputKind.BLUETOOTH, available = builtIn + OutputKind.BLUETOOTH))
        assertNull(ProximityRule.route(near = false, audioOnly = true, userChoseOutput = false, current = OutputKind.HEADSET, available = setOf(OutputKind.HEADSET, OutputKind.SPEAKER)))
        assertNull(ProximityRule.route(near = true, audioOnly = true, userChoseOutput = false, current = OutputKind.SPEAKER, available = setOf(OutputKind.SPEAKER)))
    }

    @Test
    fun theSensorIsWatchedOnlyForConnectedAudioCallsOnBuiltInOutputs() {
        assertTrue(ProximityRule.watches(connected = true, audioOnly = true, userChoseOutput = false, current = OutputKind.SPEAKER))
        assertTrue(ProximityRule.watches(connected = true, audioOnly = true, userChoseOutput = false, current = null))
        assertFalse(ProximityRule.watches(connected = false, audioOnly = true, userChoseOutput = false, current = OutputKind.SPEAKER))
        assertFalse(ProximityRule.watches(connected = true, audioOnly = false, userChoseOutput = false, current = OutputKind.SPEAKER))
        assertFalse(ProximityRule.watches(connected = true, audioOnly = true, userChoseOutput = true, current = OutputKind.SPEAKER))
        assertFalse(ProximityRule.watches(connected = true, audioOnly = true, userChoseOutput = false, current = OutputKind.HEADSET))
    }
}
