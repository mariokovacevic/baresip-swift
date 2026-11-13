package io.github.mariokovacevic.baresipkit

import org.junit.Assume.assumeTrue

object HostCore {
    fun require() {
        assumeTrue(System.getProperty("baresipkit.hostCore") == "true")
    }

    fun configuration(): BaresipConfiguration =
        BaresipConfiguration(
            modules = listOf("g711", "l16", "auconv", "auresamp", "ausine", "aufile", "fakevideo"),
            audio =
                BaresipAudioConfiguration(
                    sourceModule = "ausine",
                    playerModule = "aufile",
                    playerDevice = "/dev/null",
                ),
            extraConfiguration = "sip_listen\t\t0.0.0.0:0",
        )
}
