package io.github.mariokovacevic.baresipkit

import io.github.mariokovacevic.baresipkit.internal.PUSH_TOKEN_PARAMETERS
import io.github.mariokovacevic.baresipkit.internal.describe
import io.github.mariokovacevic.baresipkit.internal.redacted
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * The settings of one SIP account, passed to [BaresipEngine.addAccount].
 *
 * Create the settings with the [BaresipAccountConfiguration] function and change a copy with
 * [copy]:
 *
 * ```kotlin
 * val account =
 *     BaresipAccountConfiguration(aor = "sip:alice@example.com") {
 *         authPassword = password
 *         transport = BaresipTransport.TLS
 *     }
 * val id = engine.addAccount(account)
 * engine.register(id)
 * ```
 *
 * Settings added in a later release get a default that keeps the earlier behaviour. [toString]
 * shows the password as `***`.
 */
class BaresipAccountConfiguration private constructor(
    builder: Builder,
) {
    /** The address of record, for example `sip:alice@example.com`. */
    val aor: String = builder.aor

    /** The display name in the `From` header. */
    val displayName: String? = builder.displayName

    /** The registrar URI, or `null` to use the domain of [aor]. */
    val registrar: String? = builder.registrar

    /** An outbound proxy URI. */
    val outboundProxy: String? = builder.outboundProxy

    /** The SIP transport. */
    val transport: BaresipTransport = builder.transport

    /** The authentication user name, or `null` to use the user part of [aor]. */
    val authUser: String? = builder.authUser

    /** The authentication password. It is passed to the core and never logged. */
    val authPassword: String? = builder.authPassword

    /** The requested registration lifetime. */
    val registerExpires: Duration = builder.registerExpires

    /** Whether SIP Outbound (RFC 5626) is used. */
    val sipOutbound: Boolean = builder.sipOutbound

    /** Media encryption for calls of this account. */
    val mediaEncryption: BaresipMediaEncryption = builder.mediaEncryption

    /** NAT traversal settings. */
    val nat: BaresipNatConfiguration = builder.nat

    /** How DTMF is sent. */
    val dtmfMode: BaresipDtmfMode = builder.dtmfMode

    /** Extra `Contact` header parameters, for example for push routing. */
    val contactParameters: List<BaresipContactParameter> = builder.contactParameters

    /** Audio codecs for this account, or empty for the engine's list. */
    val audioCodecs: List<String> = builder.audioCodecs

    /** Video codecs for this account, or empty for the engine's list. */
    val videoCodecs: List<String> = builder.videoCodecs

    /** Whether incoming calls start a receive-only early media preview automatically. */
    val answerEarlyMedia: Boolean = builder.answerEarlyMedia

    /** Whether incoming REFER requests are followed. When `false` they are declined. */
    val acceptTransfers: Boolean = builder.acceptTransfers

    /**
     * Whether requests for a new video picture are also sent as SIP INFO (RFC 5168).
     *
     * Some endpoints, such as door stations, react only to a SIP INFO `picture_fast_update`
     * request. Incoming requests of that kind are always answered. Off by default.
     */
    val pictureUpdateOverSipInfo: Boolean = builder.pictureUpdateOverSipInfo

    /** Headers of incoming INVITEs to keep, such as `X-Device-ID`, read with [BaresipEngine.incomingHeader]. */
    val incomingHeaders: List<String> = builder.incomingHeaders

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

    /** Returns a copy of these settings with the changes made in [block]. */
    fun copy(block: Builder.() -> Unit): BaresipAccountConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipAccountConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        describe(
            "BaresipAccountConfiguration",
            "aor" to aor,
            "displayName" to displayName,
            "registrar" to registrar,
            "outboundProxy" to outboundProxy,
            "transport" to transport,
            "authUser" to authUser,
            "authPassword" to redacted(authPassword),
            "registerExpires" to registerExpires,
            "sipOutbound" to sipOutbound,
            "mediaEncryption" to mediaEncryption,
            "nat" to nat,
            "dtmfMode" to dtmfMode,
            "contactParameters" to contactParameters,
            "audioCodecs" to audioCodecs,
            "videoCodecs" to videoCodecs,
            "answerEarlyMedia" to answerEarlyMedia,
            "acceptTransfers" to acceptTransfers,
            "pictureUpdateOverSipInfo" to pictureUpdateOverSipInfo,
            "incomingHeaders" to incomingHeaders,
        )

    private fun values(): List<Any?> =
        listOf(
            aor,
            displayName,
            registrar,
            outboundProxy,
            transport,
            authUser,
            authPassword,
            registerExpires,
            sipOutbound,
            mediaEncryption,
            nat,
            dtmfMode,
            contactParameters,
            audioCodecs,
            videoCodecs,
            answerEarlyMedia,
            acceptTransfers,
            pictureUpdateOverSipInfo,
            incomingHeaders,
        )

    private fun isSendable(
        text: String,
        forbidden: String,
    ): Boolean = text.none { it.code < 0x20 || it.code == 0x7F || it in forbidden }

    /** Collects the settings of a [BaresipAccountConfiguration]; see the [BaresipAccountConfiguration] function. */
    @BaresipConfigurationDsl
    class Builder(
        /** The address of record, for example `sip:alice@example.com`. */
        var aor: String,
    ) {
        /** The display name in the `From` header, or `null` for none. */
        var displayName: String? = null

        /** The registrar URI, or `null` to use the domain of [aor]. */
        var registrar: String? = null

        /** An outbound proxy URI, or `null` for none. */
        var outboundProxy: String? = null

        /** The SIP transport, [BaresipTransport.TLS] by default. */
        var transport: BaresipTransport = BaresipTransport.TLS

        /** The authentication user name, or `null` to use the user part of [aor]. */
        var authUser: String? = null

        /** The authentication password. It is passed to the core and never logged. */
        var authPassword: String? = null

        /** The requested registration lifetime, 600 seconds by default. */
        var registerExpires: Duration = 600.seconds

        /** Whether SIP Outbound (RFC 5626) is used. Off by default. */
        var sipOutbound: Boolean = false

        /** Media encryption for calls of this account, [BaresipMediaEncryption.SRTP_OPTIONAL] by default. */
        var mediaEncryption: BaresipMediaEncryption = BaresipMediaEncryption.SRTP_OPTIONAL

        /** NAT traversal settings. */
        var nat: BaresipNatConfiguration = BaresipNatConfiguration()

        /** How DTMF is sent, [BaresipDtmfMode.AUTO] by default. */
        var dtmfMode: BaresipDtmfMode = BaresipDtmfMode.AUTO

        /** Extra `Contact` header parameters, for example for push routing. */
        var contactParameters: List<BaresipContactParameter> = emptyList()

        /** Audio codecs for this account, or empty for the engine's list. */
        var audioCodecs: List<String> = emptyList()

        /** Video codecs for this account, or empty for the engine's list. */
        var videoCodecs: List<String> = emptyList()

        /** Whether incoming calls start a receive-only early media preview automatically. Off by default. */
        var answerEarlyMedia: Boolean = false

        /** Whether incoming REFER requests are followed. When `false` they are declined. On by default. */
        var acceptTransfers: Boolean = true

        /** Whether requests for a new video picture are also sent as SIP INFO (RFC 5168). Off by default. */
        var pictureUpdateOverSipInfo: Boolean = false

        /** Headers of incoming INVITEs to keep, such as `X-Device-ID`, read with [BaresipEngine.incomingHeader]. */
        var incomingHeaders: List<String> = emptyList()

        /** Starts from the settings of [configuration]. */
        constructor(configuration: BaresipAccountConfiguration) : this(configuration.aor) {
            displayName = configuration.displayName
            registrar = configuration.registrar
            outboundProxy = configuration.outboundProxy
            transport = configuration.transport
            authUser = configuration.authUser
            authPassword = configuration.authPassword
            registerExpires = configuration.registerExpires
            sipOutbound = configuration.sipOutbound
            mediaEncryption = configuration.mediaEncryption
            nat = configuration.nat
            dtmfMode = configuration.dtmfMode
            contactParameters = configuration.contactParameters
            audioCodecs = configuration.audioCodecs
            videoCodecs = configuration.videoCodecs
            answerEarlyMedia = configuration.answerEarlyMedia
            acceptTransfers = configuration.acceptTransfers
            pictureUpdateOverSipInfo = configuration.pictureUpdateOverSipInfo
            incomingHeaders = configuration.incomingHeaders
        }

        /** Changes the [nat] settings. */
        fun nat(block: BaresipNatConfiguration.Builder.() -> Unit) {
            nat = nat.copy(block)
        }

        /** Creates the settings. */
        fun build(): BaresipAccountConfiguration = BaresipAccountConfiguration(this)
    }
}

/**
 * Creates the settings of a SIP account: the defaults, changed by [block].
 *
 * @param aor The address of record, for example `sip:alice@example.com`.
 */
fun BaresipAccountConfiguration(
    aor: String,
    block: BaresipAccountConfiguration.Builder.() -> Unit = {},
): BaresipAccountConfiguration = BaresipAccountConfiguration.Builder(aor).apply(block).build()

/**
 * A parameter added to the SIP `Contact` header of an account's REGISTER requests.
 *
 * Use contact parameters for RFC 8599 push notification routing (`pn-provider`, `pn-prid`,
 * `pn-param`) or for registrar-specific parameters. Names and values must be SIP tokens.
 * [toString] shows the value of a push token parameter, `pn-prid` or `pn-tok`, as `***`.
 */
data class BaresipContactParameter(
    /** The parameter name. */
    val name: String,
    /** The parameter value, or `null` for a flag parameter without a value. */
    val value: String?,
) {
    override fun toString(): String {
        val shown = if (name.lowercase() in PUSH_TOKEN_PARAMETERS) redacted(value) else value
        return "BaresipContactParameter(name=$name, value=$shown)"
    }
}

/**
 * NAT traversal settings for an account, part of [BaresipAccountConfiguration].
 *
 * Create them with the [BaresipNatConfiguration] function or with
 * [BaresipAccountConfiguration.Builder.nat].
 */
class BaresipNatConfiguration private constructor(
    builder: Builder,
) {
    /** The traversal method. */
    val mode: BaresipNatTraversal = builder.mode

    /** The STUN server, for example `stun:stun.example.com:3478`. */
    val stunUri: String? = builder.stunUri

    /** The TURN relay used by ICE. At most one server is supported. */
    val turnServers: List<BaresipTurnServer> = builder.turnServers

    /** How long an established call may receive no RTP before it is ended. */
    val rtpTimeout: Duration = builder.rtpTimeout

    /** Whether RTCP shares the RTP port (RFC 5761). On by default. */
    val rtcpMultiplexing: Boolean = builder.rtcpMultiplexing

    /**
     * Whether a stream that only receives sends empty RTP packets until the peer's media
     * arrives, for media relays and NATs that forward media only after they have seen a packet
     * from this side. Off by default.
     */
    val pinhole: Boolean = builder.pinhole

    /** Returns a copy of these settings with the changes made in [block]. */
    fun copy(block: Builder.() -> Unit): BaresipNatConfiguration = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipNatConfiguration && values() == other.values()

    override fun hashCode(): Int = values().hashCode()

    override fun toString(): String =
        describe(
            "BaresipNatConfiguration",
            "mode" to mode,
            "stunUri" to stunUri,
            "turnServers" to turnServers,
            "rtpTimeout" to rtpTimeout,
            "rtcpMultiplexing" to rtcpMultiplexing,
            "pinhole" to pinhole,
        )

    private fun values(): List<Any?> = listOf(mode, stunUri, turnServers, rtpTimeout, rtcpMultiplexing, pinhole)

    /** Collects the settings of a [BaresipNatConfiguration]; see the [BaresipNatConfiguration] function. */
    @BaresipConfigurationDsl
    class Builder() {
        /** The traversal method, [BaresipNatTraversal.NONE] by default. */
        var mode: BaresipNatTraversal = BaresipNatTraversal.NONE

        /** The STUN server, for example `stun:stun.example.com:3478`, or `null` for none. */
        var stunUri: String? = null

        /** The TURN relay used by ICE. At most one server is supported. */
        var turnServers: List<BaresipTurnServer> = emptyList()

        /** How long an established call may receive no RTP before it is ended, 30 seconds by default. */
        var rtpTimeout: Duration = 30.seconds

        /** Whether RTCP shares the RTP port (RFC 5761). On by default. */
        var rtcpMultiplexing: Boolean = true

        /** Whether a stream that only receives sends empty RTP packets until the peer's media arrives. Off by default. */
        var pinhole: Boolean = false

        /** Starts from the settings of [configuration]. */
        constructor(configuration: BaresipNatConfiguration) : this() {
            mode = configuration.mode
            stunUri = configuration.stunUri
            turnServers = configuration.turnServers
            rtpTimeout = configuration.rtpTimeout
            rtcpMultiplexing = configuration.rtcpMultiplexing
            pinhole = configuration.pinhole
        }

        /** Creates the settings. */
        fun build(): BaresipNatConfiguration = BaresipNatConfiguration(this)
    }
}

/** Creates NAT traversal settings: the defaults, changed by [block]. */
fun BaresipNatConfiguration(block: BaresipNatConfiguration.Builder.() -> Unit = {}): BaresipNatConfiguration = BaresipNatConfiguration.Builder().apply(block).build()

/**
 * A TURN relay used by ICE. The URI selects the transport: `turn:host:3478` (UDP),
 * `turn:host:3478?transport=tcp` or `turns:host:5349` (TLS).
 *
 * Create one with the [BaresipTurnServer] function. [toString] shows the password as `***`.
 */
class BaresipTurnServer private constructor(
    builder: Builder,
) {
    /** The TURN URI. */
    val uri: String = builder.uri

    /** The TURN username, if the server needs one. */
    val username: String? = builder.username

    /** The TURN password, if the server needs one. */
    val password: String? = builder.password

    /** Returns a copy of this server with the changes made in [block]. */
    fun copy(block: Builder.() -> Unit): BaresipTurnServer = Builder(this).apply(block).build()

    override fun equals(other: Any?): Boolean = other is BaresipTurnServer && uri == other.uri && username == other.username && password == other.password

    override fun hashCode(): Int = listOf(uri, username, password).hashCode()

    override fun toString(): String = describe("BaresipTurnServer", "uri" to uri, "username" to username, "password" to redacted(password))

    /** Collects the settings of a [BaresipTurnServer]; see the [BaresipTurnServer] function. */
    @BaresipConfigurationDsl
    class Builder(
        /** The TURN URI. */
        var uri: String,
    ) {
        /** The TURN username, or `null` when the server needs none. */
        var username: String? = null

        /** The TURN password, or `null` when the server needs none. */
        var password: String? = null

        /** Starts from the settings of [server]. */
        constructor(server: BaresipTurnServer) : this(server.uri) {
            username = server.username
            password = server.password
        }

        /** Creates the server. */
        fun build(): BaresipTurnServer = BaresipTurnServer(this)
    }
}

/**
 * Creates a TURN relay: the URI, with the credentials set in [block].
 *
 * @param uri The TURN URI, for example `turns:turn.example.com:5349`.
 */
fun BaresipTurnServer(
    uri: String,
    block: BaresipTurnServer.Builder.() -> Unit = {},
): BaresipTurnServer = BaresipTurnServer.Builder(uri).apply(block).build()
