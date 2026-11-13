package io.github.mariokovacevic.baresipkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class FileLogTest {
    private fun directory(): File = Files.createTempDirectory("FileLogTest").toFile()

    @Test
    fun writeCreatesALogFile() {
        val directory = directory()
        try {
            val log = BaresipFileLog(directory)
            log.write("hello")
            val files = log.files()
            assertEquals(1, files.size)
            assertTrue(files[0].readText().contains("[app] hello"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun writeWithTag() {
        val directory = directory()
        try {
            val log = BaresipFileLog(directory)
            log.write("entry", tag = "sip")
            assertTrue(log.files()[0].readText().contains("[sip] entry"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun anOversizedFileIsTruncated() {
        val directory = directory()
        try {
            val log = BaresipFileLog(directory, maxFileSize = 64)
            repeat(50) { log.write("line number $it with some padding to grow the file quickly") }
            val files = log.files()
            assertEquals(1, files.size)
            assertTrue(files[0].length() < 64 * 3)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun oldFilesBeyondDaysToKeepAreRemoved() {
        val directory = directory()
        try {
            for (day in listOf("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04")) {
                File(directory, "BaresipKit-$day.log").writeText("x")
            }
            val log = BaresipFileLog(directory, daysToKeep = 2)
            log.write("trigger pruning")
            assertEquals(2, log.files().size)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun handlerForwardsToNext() {
        val directory = directory()
        try {
            val log = BaresipFileLog(directory)
            val forwarded = CountDownLatch(1)
            val handler =
                log.handler { entry ->
                    assertEquals("forwarded message", entry.message)
                    forwarded.countDown()
                }
            handler.log(BaresipLogEntry(BaresipLogLevel.INFO, BaresipLogDomain.CORE, "forwarded message"))
            assertTrue(forwarded.await(1, TimeUnit.SECONDS))
            assertTrue(log.files()[0].readText().contains("[core info] forwarded message"))
        } finally {
            directory.deleteRecursively()
        }
    }
}
