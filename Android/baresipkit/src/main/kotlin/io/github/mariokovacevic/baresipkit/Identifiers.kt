package io.github.mariokovacevic.baresipkit

/** Identifies an account of an engine. Identifiers are never reused while the engine runs. */
@JvmInline
public value class BaresipAccountID(
    public val rawValue: Long,
) {
    override fun toString(): String = "account#$rawValue"
}

/** Identifies a call of an engine. After the call is released its identifier is no longer valid. */
@JvmInline
public value class BaresipCallID(
    public val rawValue: Long,
) {
    override fun toString(): String = "call#$rawValue"
}

/** Identifies an outgoing SIP MESSAGE; [BaresipMessageStatus] reports its outcome. */
@JvmInline
public value class BaresipMessageID(
    public val rawValue: Long,
) {
    override fun toString(): String = "message#$rawValue"
}
