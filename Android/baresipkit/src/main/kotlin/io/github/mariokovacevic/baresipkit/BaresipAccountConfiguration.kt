package io.github.mariokovacevic.baresipkit

import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * The settings of one SIP account, passed to [BaresipEngine.addAccount].
 *
 * ```kotlin
 * val id = engine.addAccount(BaresipAccountConfiguration(aor = "sip:alice@example.com", authPassword = password))
 * engine.register(id)
 * ```
 */
data class BaresipAccountConfiguration(
    /** The address of record, for example `sip:alice@example.com`. */
    val aor: String,
    /** The display name in the `From` header. */
    val displayName: String? = null,
    /** The registrar URI, or `null` to use the domain of [aor]. */
    val registrar: String? = null,
    /** An outbound proxy URI. */
    val outboundProxy: String? = null,
    /** The SIP transport. */
    val transport: BaresipTransport = BaresipTransport.TLS,
    /** The authentication user name, or `null` to use the user part of [aor]. */
    val authUser: String? = null,
    /** The authentication password. It is passed to the core and never logged. */
    val authPassword: String? = null,
    /** The requested registration lifetime. */
    val registerExpires: Duration = 600.seconds,
    /** Whether SIP Outbound (RFC 5626) is used. */
    val sipOutbound: Boolean = false,
    /** Media encryption for calls of this account. */
    val mediaEncryption: BaresipMediaEncryption = BaresipMediaEncryption.SRTP_OPTIONAL,
    /** NAT traversal settings. */
    val nat: BaresipNatConfiguration = BaresipNatConfiguration(),
    /** How DTMF is sent. */
    val dtmfMode: BaresipDtmfMode = BaresipDtmfMode.AUTO,
    /** Extra `Contact` header parameters, for example for push routing. */
    val contactParameters: List<BaresipContactParameter> = emptyList(),
    /** Audio codecs for this account, or empty for the engine's list. */
    val audioCodecs: List<String> = emptyList(),
    /** Video codecs for this account, or empty for the engine's list. */
    val videoCodecs: List<String> = emptyList(),
    /** Whether incoming calls start a receive-only early media preview automatically. */
    val answerEarlyMedia: Boolean = false,
    /** Whether incoming REFER requests are followed. When `false` they are declined. */
    val acceptTransfers: Boolean = true,
    /**
     * Whether requests for a new video picture are also sent as SIP INFO (RFC 5168).
     *
     * Some endpoints, such as door stations, react only to a SIP INFO `picture_fast_update`
     * request. Incoming requests of that kind are always answered. Off by default.
     */
    val pictureUpdateOverSipInfo: Boolean = false,
    /** Headers of incoming INVITEs to keep, such as `X-Device-ID`, read with [BaresipEngine.incomingHeader]. */
    val incomingHeaders: List<String> = emptyList(),
) {
    /**
     * Checks the settings without contacting a server. [BaresipEngine.addAccount] calls this
     * before adding the account.
     *
     * @throws BaresipError with [BaresipError.Code.INVALID_ARGUMENT] when the address of record is
     *   not a `sip:` or `sips:` URI with a user and a domain, a URI or the authentication user
     *   contains characters that cannot be sent, the authentication user is empty, more than one
     *   TURN server is given, or a contact parameter is not a valid SIP token.
     */
    fun validate() {
        val scheme =
            listOf("sips:", "sip:").firstOrNull { aor.startsWith(it) }
                ?: throw BaresipError.invalid("aor must start with sip: or sips:")
        val address = aor.removePrefix(scheme).split("@", limit = 2)
        if (address.size != 2 || address[0].isEmpty() || address[1].isEmpty()) {
            throw BaresipError.invalid("aor must contain user@domain")
        }
        if (!isSendable(aor, "\"<>;? ")) {
            throw BaresipError.invalid("aor must not contain quotes, angle brackets, ';', '?' or spaces")
        }
        for (uri in listOfNotNull(registrar, outboundProxy)) {
            if (!(uri.startsWith("sip:") || uri.startsWith("sips:")) || !isSendable(uri, "\"<>? ")) {
                throw BaresipError.invalid("registrar and outbound proxy must be sip: or sips: URIs")
            }
        }
        authUser?.let {
            if (it.isEmpty() || !isSendable(it, "")) {
                throw BaresipError.invalid("authUser must not be empty or contain control characters")
            }
        }
        if (nat.turnServers.size > 1) throw BaresipError.invalid("at most one TURN server is supported")
        BaresipEngine.encodeContactParameters(contactParameters)
    }

    private fun isSendable(
        text: String,
        forbidden: String,
    ): Boolean = text.none { it.code < 0x20 || it.code == 0x7F || it in forbidden }
}

/**
 * A parameter added to the SIP `Contact` header of an account's REGISTER requests.
 *
 * Use contact parameters for RFC 8599 push notification routing (`pn-provider`, `pn-prid`,
 * `pn-param`) or for registrar-specific parameters. Names and values must be SIP tokens.
 */
data class BaresipContactParameter(
    /** The parameter name. */
    val name: String,
    /** The parameter value, or `null` for a flag parameter without a value. */
    val value: String?,
)

/** NAT traversal settings for an account. */
data class BaresipNatConfiguration(
    /** The traversal method. */
    val mode: BaresipNatTraversal = BaresipNatTraversal.NONE,
    /** The STUN server, for example `stun:stun.example.com:3478`. */
    val stunUri: String? = null,
    /** The TURN relay used by ICE. At most one server is supported. */
    val turnServers: List<BaresipTurnServer> = emptyList(),
    /** How long an established call may receive no RTP before it is ended. */
    val rtpTimeout: Duration = 30.seconds,
    /** Whether RTCP shares the RTP port (RFC 5761). On by default. */
    val rtcpMultiplexing: Boolean = true,
    /**
     * Whether a stream that only receives sends empty RTP packets until the peer's media
     * arrives, for media relays and NATs that forward media only after they have seen a packet
     * from this side. Off by default.
     */
    val pinhole: Boolean = false,
)

/**
 * A TURN relay used by ICE. The URI selects the transport: `turn:host:3478` (UDP),
 * `turn:host:3478?transport=tcp` or `turns:host:5349` (TLS).
 */
data class BaresipTurnServer(
    /** The TURN URI. */
    val uri: String,
    /** The TURN username, if the server needs one. */
    val username: String? = null,
    /** The TURN password, if the server needs one. */
    val password: String? = null,
)
