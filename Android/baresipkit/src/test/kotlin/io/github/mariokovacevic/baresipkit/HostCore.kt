package io.github.mariokovacevic.baresipkit

import org.junit.Assume.assumeTrue
import java.util.UUID

object HostCore {
    val instanceUuid: UUID = UUID.fromString("00000000-0000-4000-8000-00000000b5c1")

    fun require() {
        assumeTrue(System.getProperty("baresipkit.hostCore") == "true")
    }

    fun configuration(): BaresipConfiguration =
        BaresipConfiguration(instanceUuid) {
            modules = listOf("g711", "l16", "auconv", "auresamp", "ausine", "aufile", "fakevideo")
            audio {
                sourceModule = "ausine"
                playerModule = "aufile"
                playerDevice = "/dev/null"
            }
            extraConfiguration = "sip_listen\t\t0.0.0.0:0"
        }
}
