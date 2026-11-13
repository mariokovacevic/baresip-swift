package io.github.mariokovacevic.baresipkit

import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Writes log lines to daily files, so logs of a call can be shared afterwards.
 *
 * One file per day, in [directory], with the oldest files beyond [daysToKeep] removed and a file
 * beyond [maxFileSize] truncated. Lines are written on a background thread straight to the file,
 * so nothing is lost when the process is killed.
 *
 * @param directory Where log files are written, for example `File(context.filesDir, "Logs")`.
 * @param maxFileSize The size, in bytes, beyond which a day's file is truncated and restarted.
 * @param daysToKeep The number of most recent daily files kept; older ones are removed.
 */
class BaresipFileLog(
    val directory: File,
    private val maxFileSize: Long = 50L * 1024 * 1024,
    private val daysToKeep: Int = 7,
) {
    private val executor =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "baresipkit.filelog").apply { isDaemon = true }
        }
    private val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
    private val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    private var stream: FileOutputStream? = null
    private var file: File? = null
    private var currentDay = ""

    init {
        executor.execute {
            directory.mkdirs()
            pruneOldFiles()
        }
    }

    /** Appends a line, with the time and a short [tag] shown next to it. */
    fun write(
        message: String,
        tag: String = "app",
    ) {
        val now = Date()
        executor.execute {
            val line = "${timeFormat.format(now)} [$tag] $message"
            val text = if (line.endsWith("\n")) line else line + "\n"
            runCatching { stream(now)?.write(text.toByteArray(Charsets.UTF_8)) }
        }
    }

    /**
     * Returns a log handler for [BaresipEngine.setLogHandler] that writes to the file and passes
     * each entry on to [next], for example [BaresipLogcat.handler].
     */
    fun handler(next: BaresipLogHandler? = null): BaresipLogHandler =
        BaresipLogHandler { entry ->
            write(entry.message.trim('\n', '\r'), "${entry.domain.name.lowercase()} ${entry.level.name.lowercase()}")
            next?.log(entry)
        }

    /** The log files, newest first. Waits for lines still being written. */
    fun files(): List<File> =
        executor
            .submit<List<File>> {
                runCatching { stream?.fd?.sync() }
                logFiles()
            }.get()

    private fun logFiles(): List<File> = directory.listFiles { candidate -> candidate.extension == "log" }.orEmpty().sortedByDescending { it.name }

    private fun stream(date: Date): FileOutputStream? {
        val day = dayFormat.format(date)
        val current = file
        if (day != currentDay || stream == null || current == null || current.length() > maxFileSize) {
            runCatching { stream?.close() }
            stream = null
            currentDay = day
            val next = File(directory, "BaresipKit-$day.log")
            directory.mkdirs()
            if (next.exists() && next.length() > maxFileSize) next.delete()
            stream = runCatching { FileOutputStream(next, true) }.getOrNull()
            file = next
            pruneOldFiles()
        }
        return stream
    }

    private fun pruneOldFiles() {
        logFiles().drop(daysToKeep).forEach { it.delete() }
    }
}
