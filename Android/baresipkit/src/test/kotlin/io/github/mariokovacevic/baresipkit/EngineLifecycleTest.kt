package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.sin
import kotlin.time.Duration.Companion.seconds

class EngineLifecycleTest {
    @Before
    fun requireHostCore() = HostCore.require()

    @Test
    fun createStartStop() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                assertEquals(BaresipEngineState.IDLE, engine.state)
                engine.start()
                assertTrue(engine.state == BaresipEngineState.READY || engine.state == BaresipEngineState.RUNNING)
                val id =
                    engine.addAccount(
                        BaresipAccountConfiguration(aor = "sip:alice@example.invalid", authUser = "alice", authPassword = "secret"),
                    )
                assertEquals(BaresipRegistrationState.NONE, engine.registrationState(id))
                assertEquals(mapOf(id to BaresipRegistrationState.NONE), engine.accounts())
                engine.removeAccount(id)
                engine.stop()
                assertEquals(BaresipEngineState.STOPPED, engine.state)
            }
        }

    @Test
    fun capabilitiesAndVersions() {
        assertTrue(BaresipEngine.capabilities.contains("reg.contact-params"))
        assertTrue(BaresipEngine.capabilities.contains("audio.hold-music"))
        assertTrue(BaresipEngine.capabilities.contains("call.session-timer"))
        assertFalse(BaresipEngine.coreVersion.isEmpty())
        assertEquals(BaresipEngine.AbiVersion(0, 11), BaresipEngine.abiVersion)
    }

    @Test
    fun holdMusicFileIsReadWhenTheEngineIsCreated() {
        val missing = HostCore.configuration().let { it.copy(audio = it.audio.copy(holdMusicFile = File("/nonexistent/hold.wav"))) }
        assertThrows(BaresipError::class.java) { BaresipEngine(missing).close() }

        val file = File.createTempFile("hold", ".wav")
        try {
            file.writeText("not a wave file, only text")
            val text = HostCore.configuration().let { it.copy(audio = it.audio.copy(holdMusicFile = file)) }
            assertThrows(BaresipError::class.java) { BaresipEngine(text).close() }

            file.writeBytes(wav(8000, 1))
            BaresipEngine(text).close()
        } finally {
            file.delete()
        }
    }

    @Test
    fun aSessionTimerShorterThanItsMinimumIsRejected() {
        val base = HostCore.configuration()
        assertEquals(1800.seconds, base.sessionTimer)
        assertEquals(90.seconds, base.minimumSessionTimer)
        assertThrows(BaresipError::class.java) { BaresipEngine(base.copy(sessionTimer = 60.seconds)).close() }
        BaresipEngine(base.copy(sessionTimer = 60.seconds, minimumSessionTimer = 60.seconds)).close()
        BaresipEngine(base.copy(sessionTimer = null)).close()
    }

    @Test
    fun aClosedEngineRejectsOperations() =
        runBlocking {
            val engine = BaresipEngine(HostCore.configuration())
            engine.close()
            assertEquals(BaresipEngineState.STOPPED, engine.state)
            val error = runCatching { engine.start() }.exceptionOrNull()
            assertEquals(BaresipError.Code.INVALID_STATE, (error as BaresipError).code)
        }

    @Test
    fun operationsOnUnknownCallsFailWithNotFound() =
        runBlocking {
            BaresipEngine(HostCore.configuration()).use { engine ->
                engine.start()
                val call = BaresipCallID(9999)
                for (operation in listOf<suspend () -> Unit>(
                    { engine.hangup(call) },
                    { engine.callInfo(call) },
                    { engine.callStatistics(call) },
                    { engine.incomingHeader("X-Device-ID", call) },
                )) {
                    val error = runCatching { operation() }.exceptionOrNull()
                    assertEquals(BaresipError.Code.NOT_FOUND, (error as BaresipError).code)
                }
                assertEquals(emptyList<BaresipCallID>(), engine.activeCalls())
                engine.stop()
            }
        }

    private fun wav(
        sampleRate: Int,
        seconds: Int,
    ): ByteArray {
        val frames = sampleRate * seconds
        val out = ByteArrayOutputStream()

        fun int(value: Int) =
            out.write(
                ByteBuffer
                    .allocate(4)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .putInt(value)
                    .array(),
            )

        fun short(value: Int) =
            out.write(
                ByteBuffer
                    .allocate(2)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .putShort(value.toShort())
                    .array(),
            )
        out.write("RIFF".toByteArray())
        int(36 + frames * 2)
        out.write("WAVEfmt ".toByteArray())
        int(16)
        short(1)
        short(1)
        int(sampleRate)
        int(sampleRate * 2)
        short(2)
        short(16)
        out.write("data".toByteArray())
        int(frames * 2)
        for (frame in 0 until frames) {
            short((8000 * sin(2 * PI * 440 * frame / sampleRate)).toInt())
        }
        return out.toByteArray()
    }
}
