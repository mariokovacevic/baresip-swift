package io.github.mariokovacevic.baresipkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

class CertificatesTest {
    private val certificatePem =
        """
        -----BEGIN CERTIFICATE-----
        MIIBgTCCASegAwIBAgIUQk+jbEL0eLViS+P5DkaERSmMpi4wCgYIKoZIzj0EAwIw
        FjEUMBIGA1UEAwwLVGVzdCBDbGllbnQwHhcNMjYxMTEwMDkxMTM0WhcNMzYxMTA3
        MDkxMTM0WjAWMRQwEgYDVQQDDAtUZXN0IENsaWVudDBZMBMGByqGSM49AgEGCCqG
        SM49AwEHA0IABGLCZZcppTxU99zGJA2liw2lFlCA6UjaKOM2NYtRv0OvfiNqKtsB
        F53CIEoY77H6MPHRddqchDAIiASxYsimmrCjUzBRMB0GA1UdDgQWBBS4mkKVqsWc
        9sUaIctevq+DbwZfQjAfBgNVHSMEGDAWgBS4mkKVqsWc9sUaIctevq+DbwZfQjAP
        BgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIEqJZnMoj3URh+rKlQRi
        mtrJ0DKOEsax+mmuXP30lhP0AiEAv17vbWlMsSkHhuRgZS7/MlqYpw9kgi80dS10
        vi5uRpQ=
        -----END CERTIFICATE-----
        """.trimIndent()

    private val unencryptedKeyPem =
        """
        -----BEGIN EC PRIVATE KEY-----
        MHcCAQEEIHs6FhaxXh0PODRoB9UtIis5SOJzmP+LPOEyttdowrqJoAoGCCqGSM49
        AwEHoUQDQgAEYsJllymlPFT33MYkDaWLDaUWUIDpSNoo4zY1i1G/Q69+I2oq2wEX
        ncIgShjvsfow8dF12pyEMAiIBLFiyKaasA==
        -----END EC PRIVATE KEY-----
        """.trimIndent()

    private val encryptedKeyPem =
        """
        -----BEGIN EC PRIVATE KEY-----
        Proc-Type: 4,ENCRYPTED
        DEK-Info: AES-256-CBC,EC1479096091C99400BB300630DA5E9F

        veTMkWX5BXESD5eVeXovrkNNJlhMIDmvZMrQlJ3u7pjNfwRFV89mf2EC3p4T5ul6
        MSe+M8ycZUdc0GfvTc/C1B4ehLirf2iIUV8JOKaR5dKP/in3MSSUgrATe+ycAELP
        dnU3pe407GXmqZq3H6Jwyr2bPWXCWGpRTyZr6S7Eucs=
        -----END EC PRIVATE KEY-----
        """.trimIndent()

    private fun reason(body: () -> Unit) = assertThrows(BaresipCertificateException::class.java) { body() }.reason

    @Test
    fun caBundleAcceptsPemCertificate() {
        assertEquals(certificatePem + "\n", String(BaresipCertificates.caBundle(certificatePem.toByteArray())))
    }

    @Test
    fun caBundleAcceptsDerCertificate() {
        val der =
            Base64.getDecoder().decode(
                certificatePem
                    .lines()
                    .drop(1)
                    .dropLast(1)
                    .joinToString(""),
            )
        assertEquals(certificatePem + "\n", String(BaresipCertificates.caBundle(der)))
    }

    @Test
    fun caBundleRejectsGarbage() {
        assertEquals(BaresipCertificateException.Reason.NO_CERTIFICATE, reason { BaresipCertificates.caBundle("not a cert".toByteArray()) })
    }

    @Test
    fun clientIdentityCombinesCertificateAndKey() {
        val text = String(BaresipCertificates.clientIdentity("$certificatePem\n$unencryptedKeyPem\n".toByteArray()))
        assertTrue(text.contains("BEGIN CERTIFICATE"))
        assertTrue(text.contains("BEGIN EC PRIVATE KEY"))
    }

    @Test
    fun clientIdentityRejectsWhatIsMissingOrEncrypted() {
        assertEquals(BaresipCertificateException.Reason.NO_CERTIFICATE, reason { BaresipCertificates.clientIdentity(unencryptedKeyPem.toByteArray()) })
        assertEquals(BaresipCertificateException.Reason.NO_PRIVATE_KEY, reason { BaresipCertificates.clientIdentity(certificatePem.toByteArray()) })
        assertEquals(
            BaresipCertificateException.Reason.ENCRYPTED_KEY,
            reason { BaresipCertificates.clientIdentity("$certificatePem\n$encryptedKeyPem\n".toByteArray()) },
        )
    }

    @Test
    fun splitRoundTrips() {
        val identity = BaresipCertificates.clientIdentity("$certificatePem\n$unencryptedKeyPem\n".toByteArray())
        val (certificates, key) = BaresipCertificates.split(identity)
        assertTrue(certificates.contains("BEGIN CERTIFICATE"))
        assertTrue(key.contains("BEGIN EC PRIVATE KEY"))
        assertEquals("" to "", BaresipCertificates.split(null))
    }

    @Test
    fun summariesReadTheSubject() {
        assertEquals(listOf("Test Client"), BaresipCertificates.summaries(certificatePem.toByteArray()))
        assertEquals(emptyList<String>(), BaresipCertificates.summaries(null))
    }
}
