package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.zvono.model.CallIntegration
import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.DoorShortcuts
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DoorShortcutsTest {
    private val front = Door(id = "front", name = "Front door", address = "frontdoor", code = "1234")
    private val gate = Door(id = "gate", name = "Garage gate", address = "gate", code = "4711")
    private val lobby = Door(id = "lobby", name = "Lobby", address = "lobby", code = "")
    private val back = Door(id = "back", name = "", address = "sip:backyard@pbx.example.com", code = "99")

    @Test
    fun everyDoorWithACodeGetsAnOpenShortcutInOrder() {
        val shortcuts = DoorShortcuts.of(listOf(front, lobby, gate, back))
        assertEquals(listOf("door-front", "door-gate", "door-back"), shortcuts.map { it.id })
        assertEquals(listOf("Open Front door", "Open Garage gate", "Open backyard"), shortcuts.map { it.longLabel })
        assertEquals(listOf(0, 1, 2), shortcuts.map { it.rank })
        assertEquals("gate", shortcuts[1].doorId)
    }

    @Test
    fun theListIsCappedAndLongLabelsAreShortened() {
        val many = (1..6).map { Door(id = "$it", name = "Door $it", address = "door$it", code = "1") }
        assertEquals(DoorShortcuts.LIMIT, DoorShortcuts.of(many).size)
        assertEquals(2, DoorShortcuts.of(many, limit = 2).size)
        val long = DoorShortcuts.of(listOf(front.copy(name = "The very long entrance of building B"))).single()
        assertTrue(long.shortLabel.length <= 25)
        assertTrue(long.shortLabel.endsWith("…"))
        assertEquals("Open The very long entrance of building B", long.longLabel)
        assertTrue(DoorShortcuts.of(emptyList()).isEmpty())
    }

    @Test
    fun aShortcutOrASpokenNameFindsTheDoor() {
        val doors = listOf(front, gate, lobby)
        assertEquals(gate, DoorShortcuts.door(doors, "gate", null))
        assertEquals(front, DoorShortcuts.door(doors, null, "front door"))
        assertEquals(front, DoorShortcuts.door(doors, null, "the Front door"))
        assertEquals(gate, DoorShortcuts.door(doors, "removed", "garage"))
        assertNull(DoorShortcuts.door(doors, null, "Lobby"))
        assertNull(DoorShortcuts.door(doors, "lobby", null))
        assertNull(DoorShortcuts.door(doors, null, " "))
    }

    @Test
    fun callIntegrationKeysRoundTrip() {
        for (choice in CallIntegration.entries) assertEquals(choice, CallIntegration.of(choice.key))
        assertEquals(CallIntegration.SYSTEM, CallIntegration.of(null))
        assertEquals(CallIntegration.SYSTEM, CallIntegration.of("unknown"))
    }
}
