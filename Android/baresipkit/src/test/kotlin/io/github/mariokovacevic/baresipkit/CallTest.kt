package io.github.mariokovacevic.baresipkit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.net.DatagramSocket
import java.util.concurrent.CopyOnWriteArrayList

class CallTest {
    @Before
    fun requireHostCore() = HostCore.require()

    private fun freePort(): Int = DatagramSocket(0).use { it.localPort }

    private val host: String =
        java.net.NetworkInterface
            .getNetworkInterfaces()
            .toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.toList() }
            .first { it is java.net.Inet4Address }
            .hostAddress

    private suspend fun <T> io(body: () -> T): T = withContext(Dispatchers.IO) { body() }

    private fun account(port: Int) =
        BaresipAccountConfiguration(aor = "sip:alice@$host:$port") {
            transport = BaresipTransport.UDP
            mediaEncryption = BaresipMediaEncryption.NONE
            audioCodecs = listOf("PCMU/8000/1")
            incomingHeaders = listOf("X-Device-ID")
        }

    @Test
    fun incomingCallWithDtmfMessagesAndHangup() =
        runBlocking {
            val port = freePort()
            val configuration =
                HostCore.configuration().copy {
                    extraConfiguration = "sip_listen\t\t0.0.0.0:$port"
                    ipv6 = false
                    logSipTrace = true
                }
            val log = CopyOnWriteArrayList<BaresipLogEntry>()
            BaresipEngine(configuration).use { engine ->
                engine.setLogHandler {
                    log += it
                    if (System.getenv("BSK_TEST_VERBOSE") != null) println("${it.domain} ${it.message}")
                }
                val recorder = EventRecorder.start(engine, this)
                try {
                    engine.start()
                    engine.audioSessionDidActivate()
                    val account = engine.addAccount(account(port))
                    SipPeer(host, port).use { peer ->
                        io { peer.invite(listOf("X-Device-ID: door-7")) }
                        val incoming = recorder.await("incoming call") { it as? BaresipEvent.IncomingCall }
                        val call = incoming.info.id
                        assertEquals(account, incoming.info.accountId)
                        assertTrue(incoming.info.remoteUri, incoming.info.remoteUri.startsWith("sip:bob@$host"))
                        assertEquals(BaresipCallState.INCOMING, incoming.info.state)
                        assertEquals("door-7", engine.incomingHeader(call, "X-Device-ID"))
                        assertNull(engine.incomingHeader(call, "X-Other"))

                        engine.answer(call)
                        val answer = io { peer.awaitFinal("INVITE") }
                        assertEquals(200, answer.status)
                        peer.sendRtp(answer, 400)
                        recorder.awaitCall(call, BaresipCallState.STREAMS_RUNNING)
                        val info = engine.callInfo(call)
                        assertEquals("PCMU", info.audioCodec)
                        assertEquals(BaresipMediaDirection.SEND_RECEIVE, info.audioDirection)
                        assertEquals(listOf(call), engine.activeCalls())

                        io {
                            peer.info('5')
                            peer.receive(5) { !it.isRequest && it.cseqMethod == "INFO" }
                        }
                        val dtmf = recorder.await("dtmf") { (it as? BaresipEvent.Dtmf)?.dtmf }
                        assertEquals('5', dtmf.digit)
                        assertTrue(dtmf.viaSipInfo)

                        val text = "Dobar dan, paket je pred vratima 📦"
                        io {
                            peer.message(text)
                            peer.receive(5) { !it.isRequest && it.cseqMethod == "MESSAGE" }
                        }
                        val received = recorder.await("message") { (it as? BaresipEvent.Message)?.message }
                        assertEquals(text, received.text)
                        assertEquals("text/plain", received.contentType)
                        assertTrue(received.from, received.from.startsWith("sip:bob@$host"))

                        val reply = "Silazim, hvala ✓"
                        val sent = async(Dispatchers.IO) { peer.answerRequest("MESSAGE") }
                        val id = engine.sendMessage(peer.uri, reply)
                        assertEquals(reply, sent.await().body)
                        val status =
                            recorder.await("message status") { event ->
                                (event as? BaresipEvent.MessageStatus)?.status?.takeIf { it.id == id }
                            }
                        assertTrue(status.delivered)
                        assertEquals(200, status.sipStatus)

                        assertEquals(call, engine.callStatistics(call).id)

                        val bye = async(Dispatchers.IO) { peer.answerRequest("BYE") }
                        engine.hangUp(call)
                        bye.await()
                        recorder.awaitCall(call, BaresipCallState.RELEASED)
                        assertEquals(emptyList<BaresipCallID>(), engine.activeCalls())
                    }
                    engine.stop()
                } finally {
                    recorder.stop()
                }
                assertTrue(log.any { it.domain == BaresipLogDomain.SIP })
            }
        }
}
