package io.github.mariokovacevic.baresipkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

class ConfigurationBuilderTest {
    private val instance = UUID.fromString("00000000-0000-4000-8000-000000000001")

    @Test
    fun theBuilderStartsFromTheDefaults() {
        val configuration = BaresipConfiguration { instanceUuid = instance }
        assertEquals("BaresipKit", configuration.userAgent)
        assertEquals(BaresipConfiguration.DEFAULT_MODULES, configuration.modules)
        assertEquals(10000..20000, configuration.rtpPortRange)
        assertEquals(1800.seconds, configuration.sessionTimer)
        assertEquals("aaudio", configuration.audio.sourceModule)
        assertEquals(BaresipAudioConfiguration.DEFAULT_CODECS, configuration.audio.codecs)
        assertEquals("bskcamera", configuration.video.sourceModule)
        assertEquals(BaresipTlsConfiguration.TlsVersion.TLS_1_2, configuration.tls.minimumVersion)
        val account = BaresipAccountConfiguration(aor = "sip:alice@example.com")
        assertNull(account.registrar)
        assertEquals(600.seconds, account.registerExpires)
        assertEquals(BaresipNatTraversal.NONE, account.nat.mode)
        assertTrue(account.nat.rtcpMultiplexing)
    }

    @Test
    fun copyChangesOnlyWhatTheBlockSets() {
        val configuration =
            BaresipConfiguration {
                instanceUuid = instance
                userAgent = "Test/1.0"
                audio { sourceModule = "ausine" }
            }
        val changed = configuration.copy { video { width = 320 } }
        assertEquals("Test/1.0", changed.userAgent)
        assertEquals("ausine", changed.audio.sourceModule)
        assertEquals(320, changed.video.width)
        assertEquals(480, changed.video.height)
        assertNotEquals(configuration, changed)
        assertEquals(configuration, changed.copy { video { width = 640 } })
        assertEquals(configuration.hashCode(), changed.copy { video { width = 640 } }.hashCode())
    }

    @Test
    fun tlsSettingsCompareCertificatesByContent() {
        val first = BaresipTlsConfiguration { caCertificatesPem = "ca".toByteArray() }
        val second = BaresipTlsConfiguration { caCertificatesPem = "ca".toByteArray() }
        assertEquals(first, second)
        assertEquals(first.hashCode(), second.hashCode())
        assertNotEquals(first, second.copy { caCertificatesPem = "other".toByteArray() })
    }

    @Test
    fun toStringHidesSecrets() {
        val account =
            BaresipAccountConfiguration(aor = "sip:alice@example.com") {
                authPassword = "account-secret"
                contactParameters = listOf(BaresipContactParameter("pn-prid", "push-token"), BaresipContactParameter("pn-provider", "fcm"))
                nat {
                    turnServers =
                        listOf(
                            BaresipTurnServer("turns:turn.example.com:5349") {
                                username = "bsk"
                                password = "turn-secret"
                            },
                        )
                }
            }
        val text = account.toString()
        assertTrue(text.startsWith("BaresipAccountConfiguration("))
        assertTrue(text.contains("sip:alice@example.com"))
        assertTrue(text.contains("authPassword=***"))
        assertTrue(text.contains("password=***"))
        assertTrue(text.contains("pn-provider, value=fcm"))
        for (secret in listOf("account-secret", "turn-secret", "push-token")) assertFalse(text, text.contains(secret))

        val tls = BaresipTlsConfiguration { clientCertificatePem = "PRIVATE KEY".toByteArray() }
        assertFalse(tls.toString().contains("PRIVATE KEY"))
        assertTrue(BaresipConfiguration { this.tls = tls }.toString().contains("clientCertificatePem=***"))
    }

    @Test
    fun aBuilderCanStartFromExistingSettings() {
        val account =
            BaresipAccountConfiguration(aor = "sip:alice@example.com") {
                transport = BaresipTransport.UDP
                incomingHeaders = listOf("X-Device-ID")
            }
        val rebuilt = BaresipAccountConfiguration.Builder(account).build()
        assertEquals(account, rebuilt)
        val moved = account.copy { aor = "sip:bob@example.com" }
        assertEquals("sip:bob@example.com", moved.aor)
        assertEquals(BaresipTransport.UDP, moved.transport)
    }
}
