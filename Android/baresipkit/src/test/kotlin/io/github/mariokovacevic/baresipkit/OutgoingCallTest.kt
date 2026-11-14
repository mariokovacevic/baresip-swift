package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.net.DatagramSocket

class OutgoingCallTest {
    @Before
    fun requireHostCore() = HostCore.require()

    private val host: String =
        java.net.NetworkInterface
            .getNetworkInterfaces()
            .toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.toList() }
            .first { it is java.net.Inet4Address }
            .hostAddress

    private suspend fun <T> io(body: () -> T): T = withContext(Dispatchers.IO) { body() }

    private fun withEngine(body: suspend kotlinx.coroutines.CoroutineScope.(BaresipEngine, EventRecorder, Int) -> Unit) =
        runBlocking {
            val port = DatagramSocket(0).use { it.localPort }
            val configuration =
                HostCore.configuration().copy {
                    extraConfiguration = "sip_listen\t\t0.0.0.0:$port"
                    ipv6 = false
                }
            BaresipEngine(configuration).use { engine ->
                val recorder = EventRecorder.start(engine, this)
                try {
                    engine.start()
                    engine.audioSessionDidActivate()
                    engine.addAccount(
                        BaresipAccountConfiguration(aor = "sip:alice@$host:$port") {
                            transport = BaresipTransport.UDP
                            mediaEncryption = BaresipMediaEncryption.NONE
                            audioCodecs = listOf("PCMU/8000/1")
                            dtmfMode = BaresipDtmfMode.SIP_INFO
                        },
                    )
                    body(engine, recorder, port).also { engine.stop() }
                } finally {
                    recorder.stop()
                }
            }
        }

    @Test
    fun outgoingCallHoldResumeMuteAndDtmf(): Unit =
        withEngine { engine, recorder, port ->
            SipPeer(host, port).use { peer ->
                val answered = async(Dispatchers.IO) { peer.answerInvite() }
                val call = engine.makeCall(destination = peer.uri)
                val invite = answered.await()
                assertTrue(invite.body.contains("m=audio"))
                recorder.awaitCall(call, BaresipCallState.OUTGOING_RINGING)
                recorder.awaitCall(call, BaresipCallState.CONNECTED)
                val info = engine.callInfo(call)
                assertTrue(info.isOutgoing)
                assertEquals("PCMU", info.audioCodec)

                engine.setMicrophoneMuted(call, true)
                assertTrue(engine.callInfo(call).isMicrophoneMuted)
                engine.setMicrophoneMuted(call, false)

                val held = async(Dispatchers.IO) { peer.receive(10) { it.isRequest && it.method == "INVITE" } }
                engine.hold(call)
                val hold = held.await()
                assertTrue(hold.body, hold.body.contains("a=sendonly"))
                peer.reply(hold, 200, "OK", peer.sdp("recvonly"))
                recorder.awaitCall(call, BaresipCallState.PAUSED)

                val resumed = async(Dispatchers.IO) { peer.receive(10) { it.isRequest && it.method == "INVITE" } }
                engine.resume(call)
                val resume = resumed.await()
                assertTrue(resume.body, resume.body.contains("a=sendrecv"))
                peer.reply(resume, 200, "OK", peer.sdp())
                recorder.await("resumed") { event ->
                    (event as? BaresipEvent.Call)?.takeIf {
                        it.call == call &&
                            it.state == BaresipCallState.STREAMS_RUNNING &&
                            recorder.events.indexOf(it) >
                            recorder.events.indexOfFirst { e ->
                                e is BaresipEvent.Call && e.state == BaresipCallState.PAUSED
                            }
                    }
                }

                val digit = async(Dispatchers.IO) { peer.answerRequest("INFO") }
                engine.sendDtmf(call, "7")
                assertTrue(digit.await().body.contains("Signal=7"))

                val bye = async(Dispatchers.IO) { peer.answerRequest("BYE") }
                engine.hangUp(call)
                bye.await()
                recorder.awaitCall(call, BaresipCallState.RELEASED)
            }
        }

    @Test
    fun aRejectedCallFailsWithTheSipStatus(): Unit =
        withEngine { engine, recorder, port ->
            SipPeer(host, port).use { peer ->
                val rejected = async(Dispatchers.IO) { peer.rejectInvite(486, "Busy Here") }
                val call = engine.makeCall(destination = peer.uri)
                rejected.await()
                val failed =
                    recorder.await("call failed") { event ->
                        (event as? BaresipEvent.Call)?.takeIf { it.call == call && it.error != null }
                    }
                assertEquals(486, failed.error?.sipStatus)
                recorder.awaitCall(call, BaresipCallState.RELEASED)
            }
        }

    @Test
    fun anIncomingCallIsRejectedWithTheGivenStatus(): Unit =
        withEngine { engine, recorder, port ->
            SipPeer(host, port).use { peer ->
                io { peer.invite() }
                val incoming = recorder.await("incoming") { it as? BaresipEvent.IncomingCall }
                engine.reject(incoming.info.id, 603, "Decline")
                assertEquals(603, io { peer.awaitFinal("INVITE") }.status)
                recorder.awaitCall(incoming.info.id, BaresipCallState.RELEASED)
            }
        }
}
