package io.github.mariokovacevic.baresipkit.zvono.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.util.Base64
import java.util.UUID

interface KeyValueStore {
    fun read(key: String): String?

    fun write(
        key: String,
        value: String?,
    )
}

class MemoryStore : KeyValueStore {
    private val values = HashMap<String, String>()

    override fun read(key: String): String? = synchronized(values) { values[key] }

    override fun write(
        key: String,
        value: String?,
    ) {
        synchronized(values) { if (value == null) values.remove(key) else values[key] = value }
    }
}

class SettingsStore(
    private val values: KeyValueStore,
    private val secrets: KeyValueStore,
    private val logsSipMessagesByDefault: Boolean = false,
) {
    private val json =
        Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
            coerceInputValues = true
        }

    var settings: SipSettings
        get() = decode(SETTINGS, SipSettings.serializer()) ?: SipSettings()
        set(value) = encode(SETTINGS, SipSettings.serializer(), value)

    var password: String
        get() = secrets.read(PASSWORD).orEmpty()
        set(value) = secrets.write(PASSWORD, value.ifEmpty { null })

    var turnPassword: String
        get() = secrets.read(TURN_PASSWORD).orEmpty()
        set(value) = secrets.write(TURN_PASSWORD, value.ifEmpty { null })

    var doors: List<Door>
        get() = decode(DOORS, ListSerializer(Door.serializer())).orEmpty()
        set(value) = encode(DOORS, ListSerializer(Door.serializer()), value)

    var contacts: List<Contact>
        get() = decode(CONTACTS, ListSerializer(Contact.serializer())).orEmpty()
        set(value) = encode(CONTACTS, ListSerializer(Contact.serializer()), value)

    var history: List<CallRecord>
        get() = decode(HISTORY, ListSerializer(CallRecord.serializer())).orEmpty()
        set(value) = encode(HISTORY, ListSerializer(CallRecord.serializer()), value.take(CallRecord.LIMIT))

    var ringtone: Ringtone
        get() = Ringtone.of(values.read(RINGTONE))
        set(value) = values.write(RINGTONE, value.key)

    var callIntegration: CallIntegration
        get() = CallIntegration.of(values.read(CALL_INTEGRATION))
        set(value) = values.write(CALL_INTEGRATION, value.key)

    var logsSipMessages: Boolean
        get() = values.read(LOG_SIP_MESSAGES)?.toBooleanStrictOrNull() ?: logsSipMessagesByDefault
        set(value) = values.write(LOG_SIP_MESSAGES, value.toString())

    var caCertificates: ByteArray?
        get() = values.read(CA_CERTIFICATES)?.let { Base64.getDecoder().decode(it) }
        set(value) = values.write(CA_CERTIFICATES, value?.let { Base64.getEncoder().encodeToString(it) })

    var clientIdentity: ByteArray?
        get() = secrets.read(CLIENT_IDENTITY)?.let { Base64.getDecoder().decode(it) }
        set(value) = secrets.write(CLIENT_IDENTITY, value?.let { Base64.getEncoder().encodeToString(it) })

    val instanceUuid: UUID
        get() {
            values.read(INSTANCE)?.let { stored -> runCatching { UUID.fromString(stored) }.getOrNull()?.let { return it } }
            return UUID.randomUUID().also { values.write(INSTANCE, it.toString()) }
        }

    fun clear() {
        for (key in listOf(SETTINGS, DOORS, CONTACTS, HISTORY, RINGTONE, CA_CERTIFICATES, CALL_INTEGRATION)) values.write(key, null)
        for (key in listOf(PASSWORD, TURN_PASSWORD, CLIENT_IDENTITY)) secrets.write(key, null)
    }

    private fun <T> decode(
        key: String,
        serializer: KSerializer<T>,
    ): T? = values.read(key)?.let { runCatching { json.decodeFromString(serializer, it) }.getOrNull() }

    private fun <T> encode(
        key: String,
        serializer: KSerializer<T>,
        value: T,
    ) {
        values.write(key, json.encodeToString(serializer, value))
    }

    private companion object {
        const val SETTINGS = "sip.settings"
        const val PASSWORD = "sip.password"
        const val TURN_PASSWORD = "turn.password"
        const val DOORS = "doors"
        const val CONTACTS = "contacts"
        const val HISTORY = "call.history"
        const val RINGTONE = "ringtone"
        const val LOG_SIP_MESSAGES = "log.sipMessages"
        const val CA_CERTIFICATES = "tls.ca"
        const val CLIENT_IDENTITY = "tls.client"
        const val INSTANCE = "sip.instance"
        const val CALL_INTEGRATION = "callIntegration"
    }
}
