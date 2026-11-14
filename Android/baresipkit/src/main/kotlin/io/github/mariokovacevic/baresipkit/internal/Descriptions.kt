package io.github.mariokovacevic.baresipkit.internal

internal const val REDACTED = "***"

internal val PUSH_TOKEN_PARAMETERS = setOf("pn-prid", "pn-tok")

internal fun describe(
    type: String,
    vararg fields: Pair<String, Any?>,
): String = fields.joinToString(prefix = "$type(", postfix = ")") { (name, value) -> "$name=$value" }

internal fun redacted(secret: Any?): String? = secret?.let { REDACTED }

internal fun ByteArray?.sizeDescription(): String? = this?.let { "$size bytes" }
