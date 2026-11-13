package io.github.mariokovacevic.baresipkit.zvono

import io.github.mariokovacevic.baresipkit.BaresipDtmfMode
import io.github.mariokovacevic.baresipkit.BaresipNatTraversal
import io.github.mariokovacevic.baresipkit.BaresipTransport
import io.github.mariokovacevic.baresipkit.zvono.model.CallIntegration
import io.github.mariokovacevic.baresipkit.zvono.model.CallRecord
import io.github.mariokovacevic.baresipkit.zvono.model.Contact
import io.github.mariokovacevic.baresipkit.zvono.model.Door
import io.github.mariokovacevic.baresipkit.zvono.model.EngineOptions
import io.github.mariokovacevic.baresipkit.zvono.model.MemoryStore
import io.github.mariokovacevic.baresipkit.zvono.model.Ringtone
import io.github.mariokovacevic.baresipkit.zvono.model.SettingsStore
import io.github.mariokovacevic.baresipkit.zvono.model.SipSettings
import io.github.mariokovacevic.baresipkit.zvono.model.accountConfiguration
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

class SettingsStoreTest {
    private val values = MemoryStore()
    private val secrets = MemoryStore()
    private val store = SettingsStore(values, secrets)

    @Test
    fun everythingSavedIsReadBack() {
        val settings =
            SipSettings(
                domain = "pbx.example.com",
                port = "5062",
                transport = BaresipTransport.TCP,
                username = "alice",
                natMode = BaresipNatTraversal.ICE,
                turnUri = "turns:turn.example.com:5349",
                dtmfMode = BaresipDtmfMode.AUTO,
                registerExpiresSeconds = 86400,
                ringPicture = false,
                engine = EngineOptions(ipv6 = false, videoHeight = 720),
            )
        store.settings = settings
        store.password = "secret"
        store.doors = listOf(Door(id = "d", name = "Front door", address = "frontdoor", code = "1234", replyDigit = "9"))
        store.contacts = listOf(Contact(id = "c", name = "Reception", address = "reception"))
        store.history = List(CallRecord.LIMIT + 5) { CallRecord(uri = "sip:$it@pbx.example.com", name = "$it", outgoing = it % 2 == 0, startedAt = it.toLong()) }
        store.ringtone = Ringtone.BELLS
        store.callIntegration = CallIntegration.IN_APP
        store.caCertificates = byteArrayOf(1, 2, 3)
        store.clientIdentity = byteArrayOf(4, 5)

        val reread = SettingsStore(values, secrets)
        assertEquals(settings, reread.settings)
        assertEquals("secret", reread.password)
        assertEquals("9", reread.doors.single().replyDigit)
        assertEquals("Reception", reread.contacts.single().name)
        assertEquals(CallRecord.LIMIT, reread.history.size)
        assertEquals("sip:0@pbx.example.com", reread.history.first().uri)
        assertEquals(Ringtone.BELLS, reread.ringtone)
        assertEquals(CallIntegration.IN_APP, reread.callIntegration)
        assertArrayEquals(byteArrayOf(1, 2, 3), reread.caCertificates)
        assertArrayEquals(byteArrayOf(4, 5), reread.clientIdentity)
        assertEquals(reread.instanceUuid, SettingsStore(values, secrets).instanceUuid)
    }

    @Test
    fun secretsStayOutOfThePlainStore() {
        store.password = "secret"
        store.clientIdentity = byteArrayOf(9)
        store.settings = SipSettings(domain = "pbx.example.com", username = "alice")
        assertNull(values.read("sip.password"))
        assertEquals("secret", secrets.read("sip.password"))
        assertFalse(values.read("sip.settings")!!.contains("secret"))
    }

    @Test
    fun missingKeysKeepTheirDefaultsAndUnknownKeysAreIgnored() {
        values.write("sip.settings", """{"domain":"pbx.example.com","username":"bob","later":"setting"}""")
        val settings = store.settings
        assertEquals("pbx.example.com", settings.domain)
        assertEquals(BaresipTransport.TLS, settings.transport)
        assertTrue(settings.previewAudio)
        assertTrue(settings.ringPicture)
        assertEquals(CallIntegration.SYSTEM, store.callIntegration)
        assertEquals(600, settings.registerExpiresSeconds)
        values.write("sip.settings", "not json")
        assertEquals(SipSettings(), store.settings)
        assertEquals(Ringtone.CHIME, store.ringtone)
        assertFalse(store.logsSipMessages)
        assertTrue(SettingsStore(values, secrets, logsSipMessagesByDefault = true).logsSipMessages)
    }

    @Test
    fun clearRemovesTheAccountAndItsSecrets() {
        store.settings = SipSettings(domain = "pbx.example.com", username = "alice")
        store.password = "secret"
        store.clear()
        assertFalse(store.settings.isComplete)
        assertEquals("", store.password)
    }

    @Test
    fun theAccountIsBuiltFromTheSettings() {
        val settings =
            SipSettings(
                domain = " pbx.example.com ",
                port = "5061",
                username = "alice",
                outboundProxy = "proxy.example.com",
                natMode = BaresipNatTraversal.ICE,
                stunUri = "stun:stun.example.com",
                turnUri = "turn:turn.example.com",
                turnUser = "t",
                registerExpiresSeconds = 30,
                audioCodecs = "opus, PCMA",
            )
        val account = accountConfiguration(settings, "secret", "turn")
        assertEquals("sip:alice@pbx.example.com", account.aor)
        assertEquals("sip:pbx.example.com:5061;transport=tls", account.registrar)
        assertEquals("sip:proxy.example.com;transport=tls;lr", account.outboundProxy)
        assertEquals("alice", account.authUser)
        assertEquals(60.seconds, account.registerExpires)
        assertEquals("stun:stun.example.com", account.nat.stunUri)
        assertEquals(
            "turn",
            account.nat.turnServers
                .single()
                .password,
        )
        assertEquals(listOf("opus", "PCMA"), account.audioCodecs)
        assertTrue(account.answerEarlyMedia)
        assertEquals(listOf("X-Call-UUID"), account.incomingHeaders)
        assertEquals("7 days", SipSettings.durationText(604_800))
        assertEquals("1 hour", SipSettings.durationText(3600))
        assertEquals("10 min", SipSettings.durationText(600))
    }
}
