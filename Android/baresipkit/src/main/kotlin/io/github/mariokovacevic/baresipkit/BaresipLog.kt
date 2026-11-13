package io.github.mariokovacevic.baresipkit

/** The severity of a log line. */
enum class BaresipLogLevel {
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
enum class BaresipLogDomain {
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

/** One line of engine log output, passed to the handler set with [BaresipEngine.setLogHandler]. */
data class BaresipLogEntry(
    /** The severity. */
    val level: BaresipLogLevel,
    /** Where the line comes from. */
    val domain: BaresipLogDomain,
    /** The text, with credentials redacted. */
    val message: String,
)

/** Receives log lines on the engine's thread; it must return quickly. */
fun interface BaresipLogHandler {
    /** Handles one log line. */
    fun log(entry: BaresipLogEntry)
}
