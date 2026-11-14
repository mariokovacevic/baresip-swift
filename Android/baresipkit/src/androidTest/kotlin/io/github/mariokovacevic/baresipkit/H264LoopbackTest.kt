package io.github.mariokovacevic.baresipkit

import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.net.DatagramSocket
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class H264LoopbackTest {
    private val host: String =
        java.net.NetworkInterface
            .getNetworkInterfaces()
            .toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.toList() }
            .first { it is java.net.Inet4Address }
            .hostAddress!!

    @Test
    fun mediaCodecEncodesAndDecodesACallsVideo() =
        runBlocking {
            val port = DatagramSocket(0).use { it.localPort }
            val configuration =
                BaresipConfiguration(UUID.fromString("00000000-0000-4000-8000-0000000264a1")) {
                    modules = listOf("g711", "auconv", "auresamp", "ausine", "aufile", "fakevideo")
                    audio {
                        sourceModule = "ausine"
                        playerModule = "aufile"
                        playerDevice = "/dev/null"
                    }
                    video {
                        sourceModule = "fakevideo"
                        width = 320
                        height = 240
                        framesPerSecond = 15
                    }
                    extraConfiguration = "sip_listen\t\t0.0.0.0:$port"
                    ipv6 = false
                }
            BaresipEngine(configuration).use { engine ->
                engine.setLogHandler { println("${it.domain} ${it.message}") }
                val recorder = EventRecorder.start(engine, this)
                engine.start()
                engine.addAccount(
                    BaresipAccountConfiguration(aor = "sip:alice@$host:$port") {
                        transport = BaresipTransport.UDP
                        mediaEncryption = BaresipMediaEncryption.NONE
                        audioCodecs = listOf("PCMU/8000/1")
                        videoCodecs = listOf("H264")
                    },
                )
                SipPeer(host, port).use { peer ->
                    val answered = async(Dispatchers.IO) { peer.answerInvite(h264 = true) }
                    val call = engine.makeCall(destination = peer.uri, video = true)
                    val offer = answered.await()
                    assertTrue(offer.body, offer.body.contains("H264/90000"))
                    peer.echoVideo(offer, 30)
                    val frames = AtomicInteger()
                    val size = AtomicReference<Pair<Int, Int>>()
                    engine.setVideoRenderer(
                        call,
                        object : BaresipVideoRenderer {
                            override fun render(frame: BaresipVideoFrame) {
                                frames.incrementAndGet()
                            }

                            override fun didChangeSize(
                                width: Int,
                                height: Int,
                            ) = size.set(width to height)
                        },
                    )
                    recorder.awaitCall(call, BaresipCallState.CONNECTED)
                    repeat(300) {
                        if (frames.get() >= 10) return@repeat
                        delay(50)
                    }
                    assertTrue("decoded frames: ${frames.get()}", frames.get() >= 10)
                    assertEquals(320 to 240, size.get())
                    assertEquals("H264", engine.callInfo(call).videoCodec)
                    val bye = async(Dispatchers.IO) { peer.answerRequest("BYE") }
                    engine.hangUp(call)
                    bye.await()
                }
                engine.stop()
                recorder.stop()
            }
        }
}
