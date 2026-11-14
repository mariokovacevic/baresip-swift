package io.github.mariokovacevic.baresipkit

/** The severity of a log line. */
public enum class BaresipLogLevel {
    /** Detail for debugging. */
    DEBUG,

    /** Normal operation. */
    INFO,

    /** Something unexpected that the engine handled. */
    WARNING,

    /** A failure. */
    ERROR,
    ;

    internal companion object {
        fun of(code: Int): BaresipLogLevel = entries.getOrElse(code) { ERROR }
    }
}

/** The part of the engine a log line comes from. */
public enum class BaresipLogDomain {
    /** The engine itself. */
    CORE,

    /** SIP signaling. */
    SIP,

    /** Audio and video. */
    MEDIA,
    ;

    internal companion object {
        fun of(code: Int): BaresipLogDomain = entries.getOrElse(code) { CORE }
    }
}

/**
 * One line of engine log output, passed to the handler set with [BaresipEngine.setLogHandler].
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
public data class BaresipLogEntry(
    /** The severity. */
    val level: BaresipLogLevel,
    /** Where the line comes from. */
    val domain: BaresipLogDomain,
    /** The text, with credentials redacted. */
    val message: String,
)

/** Receives log lines on the engine's thread; it must return quickly. */
public fun interface BaresipLogHandler {
    /** Handles one log line. */
    public fun log(entry: BaresipLogEntry)
}
