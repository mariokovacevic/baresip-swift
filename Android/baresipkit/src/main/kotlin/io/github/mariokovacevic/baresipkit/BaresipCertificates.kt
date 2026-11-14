package io.github.mariokovacevic.baresipkit

import java.io.ByteArrayInputStream
import java.security.cert.CertificateException
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.Base64

/** An error from [BaresipCertificates]. */
class BaresipCertificateException(
    /** What went wrong. */
    val reason: Reason,
) : Exception(reason.description) {
    /** What went wrong with a certificate file. */
    enum class Reason(
        internal val description: String,
    ) {
        /** The file could not be read. */
        UNREADABLE("The file could not be read."),

        /** No certificate was found (expected PEM or DER). */
        NO_CERTIFICATE("No certificate found (expected PEM or DER)."),

        /** A client certificate needs its private key, in PEM. */
        NO_PRIVATE_KEY("The client certificate needs its private key, in PEM."),

        /** The private key is encrypted; only unencrypted keys are supported. */
        ENCRYPTED_KEY("Encrypted private keys are not supported; export the key without a passphrase."),

        /** A certificate is not valid. */
        INVALID_CERTIFICATE("A certificate is not valid."),
    }
}

/**
 * Parses and validates PEM-encoded certificates and keys for [BaresipTlsConfiguration]. The
 * results are exactly the PEM that [BaresipTlsConfiguration.caCertificatesPem] and
 * [BaresipTlsConfiguration.clientCertificatePem] accept.
 */
object BaresipCertificates {
    internal class Block(
        val label: String,
        val der: ByteArray,
        val encrypted: Boolean,
    )

    private const val BEGIN = "-----BEGIN "
    private const val END = "-----END "
    private const val MARKER_END = "-----"
    private val COMMON_NAME = Regex("(?:^|,)\\s*CN=((?:\\\\.|[^,])*)")

    internal fun blocks(data: ByteArray): List<Block> {
        val raw =
            runCatching {
                Charsets.UTF_8
                    .newDecoder()
                    .decode(java.nio.ByteBuffer.wrap(data))
                    .toString()
            }.getOrNull() ?: return emptyList()
        val text = raw.replace(Regex("-----(BEGIN|END) [A-Z0-9 ]+-----")) { "\n${it.value}\n" }
        val result = mutableListOf<Block>()
        var label: String? = null
        val body = StringBuilder()
        var encrypted = false
        for (rawLine in text.lines()) {
            val line = rawLine.trim()
            val current = label
            when {
                line.startsWith(BEGIN) && line.endsWith(MARKER_END) -> {
                    label = line.removePrefix(BEGIN).removeSuffix(MARKER_END)
                    body.clear()
                    encrypted = false
                }
                line.startsWith(END) && current != null -> {
                    runCatching { Base64.getDecoder().decode(body.toString()) }.getOrNull()?.let {
                        result += Block(current, it, encrypted || current.startsWith("ENCRYPTED"))
                    }
                    label = null
                }
                current != null && line.contains(':') -> {
                    if (line.startsWith("Proc-Type:") && line.contains("ENCRYPTED") || line.startsWith("DEK-Info:")) {
                        encrypted = true
                    }
                }
                current != null -> body.append(line.filterNot { it.isWhitespace() })
            }
        }
        return result
    }

    private fun encode(
        der: ByteArray,
        label: String,
    ): String {
        val b64 = Base64.getMimeEncoder(64, "\n".toByteArray()).encodeToString(der)
        return "-----BEGIN $label-----\n$b64\n-----END $label-----\n"
    }

    private fun parse(der: ByteArray): X509Certificate? =
        try {
            CertificateFactory.getInstance("X.509").generateCertificate(ByteArrayInputStream(der)) as? X509Certificate
        } catch (_: CertificateException) {
            null
        }

    /**
     * Validates a CA bundle and returns it as PEM for [BaresipTlsConfiguration.caCertificatesPem].
     * [data] may already be PEM (one or more `CERTIFICATE` blocks) or a single DER certificate.
     *
     * @throws BaresipCertificateException when no certificate is found or one does not parse.
     */
    fun caBundle(data: ByteArray): ByteArray {
        val certificates = blocks(data).filter { it.label == "CERTIFICATE" }
        val ders =
            if (certificates.isEmpty()) {
                parse(data) ?: throw BaresipCertificateException(BaresipCertificateException.Reason.NO_CERTIFICATE)
                listOf(data)
            } else {
                certificates.map { it.der }
            }
        if (ders.any { parse(it) == null }) {
            throw BaresipCertificateException(BaresipCertificateException.Reason.INVALID_CERTIFICATE)
        }
        return ders.joinToString("") { encode(it, "CERTIFICATE") }.toByteArray(Charsets.UTF_8)
    }

    /**
     * Validates a client identity (certificates plus an unencrypted private key) and returns it as
     * PEM for [BaresipTlsConfiguration.clientCertificatePem].
     *
     * @throws BaresipCertificateException when no certificate or key is found, the key is
     *   encrypted, or a certificate does not parse.
     */
    fun clientIdentity(data: ByteArray): ByteArray {
        val all = blocks(data)
        val certificates = all.filter { it.label == "CERTIFICATE" }
        if (certificates.isEmpty()) throw BaresipCertificateException(BaresipCertificateException.Reason.NO_CERTIFICATE)
        val key =
            all.firstOrNull { it.label.endsWith("PRIVATE KEY") }
                ?: throw BaresipCertificateException(BaresipCertificateException.Reason.NO_PRIVATE_KEY)
        if (key.encrypted) throw BaresipCertificateException(BaresipCertificateException.Reason.ENCRYPTED_KEY)
        if (certificates.any { parse(it.der) == null }) {
            throw BaresipCertificateException(BaresipCertificateException.Reason.INVALID_CERTIFICATE)
        }
        val pem = certificates.joinToString("") { encode(it.der, "CERTIFICATE") } + encode(key.der, key.label)
        return pem.toByteArray(Charsets.UTF_8)
    }

    /**
     * Splits a client identity, as returned by [clientIdentity], into its certificate and key text,
     * for editing. Used by the sample app; not covered by Semantic Versioning.
     */
    @BaresipInternalApi
    fun split(identity: ByteArray?): Pair<String, String> {
        if (identity == null) return "" to ""
        val all = blocks(identity)
        val certificates = all.filter { it.label == "CERTIFICATE" }.joinToString("") { encode(it.der, it.label) }
        val key = all.firstOrNull { it.label.endsWith("PRIVATE KEY") }?.let { encode(it.der, it.label) }.orEmpty()
        return certificates to key
    }

    /** Human-readable subject summaries of the certificates in [pem], for display. */
    fun summaries(pem: ByteArray?): List<String> {
        if (pem == null) return emptyList()
        return blocks(pem).filter { it.label == "CERTIFICATE" }.mapNotNull { parse(it.der) }.map { certificate ->
            val name = certificate.subjectX500Principal.name
            COMMON_NAME
                .find(name)
                ?.groupValues
                ?.get(1)
                ?.replace(Regex("\\\\(.)"), "$1") ?: name.ifEmpty { "certificate" }
        }
    }
}
