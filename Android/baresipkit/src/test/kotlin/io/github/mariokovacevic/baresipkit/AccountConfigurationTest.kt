package io.github.mariokovacevic.baresipkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AccountConfigurationTest {
    @Before
    fun requireHostCore() = HostCore.require()

    private fun rejects(account: BaresipAccountConfiguration) {
        val error = assertThrows(BaresipError::class.java) { account.validate() }
        assertEquals(BaresipError.Code.INVALID_ARGUMENT, error.code)
    }

    @Test
    fun validation() {
        BaresipAccountConfiguration(aor = "sip:alice@example.com").validate()
        rejects(BaresipAccountConfiguration(aor = "alice@example.com"))
        rejects(BaresipAccountConfiguration(aor = "sip:example.com"))
        rejects(BaresipAccountConfiguration(aor = "sip:a@b") { authUser = "" })
    }

    @Test
    fun validationRejectsWhatCannotBeSent() {
        val aor = "sip:alice@example.com"
        rejects(BaresipAccountConfiguration(aor = "sip:@example.com"))
        rejects(BaresipAccountConfiguration(aor = "sip:alice@"))
        rejects(BaresipAccountConfiguration(aor = "sip:alice@example.com?transport=udp"))
        rejects(BaresipAccountConfiguration(aor = "sip:alice@example.com;transport=udp"))
        rejects(BaresipAccountConfiguration(aor = "sip:alice@example.com\r\nX-Injected: 1"))
        rejects(BaresipAccountConfiguration(aor = aor) { registrar = "example.com" })
        rejects(BaresipAccountConfiguration(aor = aor) { outboundProxy = "sip:proxy.example.com\r\nX: 1" })
        rejects(BaresipAccountConfiguration(aor = aor) { authUser = "alice\nbob" })
        BaresipAccountConfiguration(aor = "sips:alice@example.com") { registrar = "sip:registrar.example.com:5061;transport=tls" }
            .validate()
    }

    @Test
    fun onlyOneTurnServerIsAccepted() {
        val turn =
            BaresipTurnServer("turn:turn.example.com:3478") {
                username = "user"
                password = "secret"
            }
        val account =
            BaresipAccountConfiguration(aor = "sip:alice@example.com") {
                nat {
                    mode = BaresipNatTraversal.ICE
                    turnServers = listOf(turn)
                }
            }
        account.validate()
        rejects(account.copy { nat { turnServers = listOf(turn, turn) } })
    }

    @Test
    fun defaultsAreSecure() {
        val configuration = BaresipConfiguration(HostCore.instanceUuid)
        assertEquals(BaresipTlsConfiguration.TlsVersion.TLS_1_2, configuration.tls.minimumVersion)
        val account = BaresipAccountConfiguration(aor = "sip:alice@example.com")
        assertEquals(BaresipTransport.TLS, account.transport)
        assertEquals(BaresipMediaEncryption.SRTP_OPTIONAL, account.mediaEncryption)
    }

    @Test
    fun contactParameterEncodingPreservesSeparators() {
        val parameters =
            listOf(
                BaresipContactParameter("app-id", "com.example.app"),
                BaresipContactParameter("pn-type", "fcm"),
                BaresipContactParameter("pn-tok", "0123abcd:remote&ffff0000:voip"),
                BaresipContactParameter("pn-silent", "1"),
                BaresipContactParameter("pn-timeout", "0"),
            )
        assertEquals(
            "app-id=com.example.app;pn-type=fcm;pn-tok=0123abcd:remote&ffff0000:voip;pn-silent=1;pn-timeout=0",
            BaresipEngine.encodeContactParameters(parameters),
        )
    }

    @Test
    fun contactParameterEncodingRejectsSeparatorsAndSpaces() {
        for (parameter in listOf(
            BaresipContactParameter("pn-tok", "a;b"),
            BaresipContactParameter("pn tok", "a"),
            BaresipContactParameter("pn-tok", "a b"),
        )) {
            val error = assertThrows(BaresipError::class.java) { BaresipEngine.encodeContactParameters(listOf(parameter)) }
            assertEquals(BaresipError.Code.INVALID_ARGUMENT, error.code)
        }
    }

    @Test
    fun emptyContactParametersAreAllowed() {
        assertEquals("", BaresipEngine.encodeContactParameters(emptyList()))
    }
}
