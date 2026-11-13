package io.github.mariokovacevic.baresipkit

/** Identifies an account of an engine. Identifiers are never reused while the engine runs. */
@JvmInline
value class BaresipAccountID(
    val rawValue: Long,
) {
    override fun toString(): String = "account#$rawValue"
}

/** Identifies a call of an engine. After the call is released its identifier is no longer valid. */
@JvmInline
value class BaresipCallID(
    val rawValue: Long,
) {
    override fun toString(): String = "call#$rawValue"
}

/** Identifies an outgoing SIP MESSAGE; [BaresipMessageStatus] reports its outcome. */
@JvmInline
value class BaresipMessageID(
    val rawValue: Long,
) {
    override fun toString(): String = "message#$rawValue"
}
