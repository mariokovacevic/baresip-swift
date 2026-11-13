package io.github.mariokovacevic.baresipkit

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException
import kotlin.random.Random

class SipMessage(
    val startLine: String,
    val headers: List<Pair<String, String>>,
    val body: String,
) {
    val isRequest: Boolean get() = !startLine.startsWith("SIP/2.0")
    val method: String get() = startLine.substringBefore(' ')
    val status: Int get() = startLine.split(' ')[1].toInt()
    val cseqMethod: String get() = header("CSeq").substringAfter(' ').trim()

    fun header(name: String): String = headers.firstOrNull { it.first.equals(name, ignoreCase = true) }?.second.orEmpty()

    fun all(name: String): List<String> = headers.filter { it.first.equals(name, ignoreCase = true) }.map { it.second }

    companion object {
        fun parse(text: String): SipMessage {
            val head = text.substringBefore("\r\n\r\n")
            val body = text.substringAfter("\r\n\r\n", "")
            val lines = head.split("\r\n")
            val headers = lines.drop(1).map { it.substringBefore(':').trim() to it.substringAfter(':').trim() }
            return SipMessage(lines.first(), headers, body)
        }
    }
}

class SipPeer(
    private val host: String,
    private val enginePort: Int,
) : AutoCloseable {
    private val address = InetAddress.getByName(host)
    private val sip = DatagramSocket(0, address).apply { soTimeout = 200 }
    private val rtp = DatagramSocket(0, address)
    private val video = DatagramSocket(0, address).apply { soTimeout = 200 }
    val port: Int = sip.localPort
    val uri = "sip:bob@$host:$port"
    val engineUri = "sip:alice@$host:$enginePort"
    private val callId = "${Random.nextLong().toULong().toString(16)}@peer"
    private val tag = Random.nextInt().toUInt().toString(16)
    private var remoteTag = ""
    private var remoteTarget = engineUri
    private var cseq = 0

    private var sdpVersion = 1

    fun sdp(
        direction: String = "sendrecv",
        h264: Boolean = false,
    ): String =
        "v=0\r\no=- 1 ${sdpVersion++} IN IP4 $host\r\ns=-\r\nc=IN IP4 $host\r\nt=0 0\r\n" +
            "m=audio ${rtp.localPort} RTP/AVP 0 101\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:101 telephone-event/8000\r\n" +
            "a=$direction\r\n" +
            if (h264) {
                "m=video ${video.localPort} RTP/AVP 96\r\na=rtpmap:96 H264/90000\r\n" +
                    "a=fmtp:96 packetization-mode=1;profile-level-id=42e01f\r\na=sendrecv\r\n"
            } else {
                ""
            }

    fun echoVideo(
        offer: SipMessage,
        seconds: Int,
    ): Thread {
        val port =
            Regex("m=video (\\d+)")
                .find(offer.body)
                ?.groupValues
                ?.get(1)
                ?.toInt() ?: error("no video port")
        val target = Regex("c=IN IP4 ([0-9.]+)").find(offer.body)?.groupValues?.get(1) ?: host
        val destination = InetAddress.getByName(target)
        return Thread {
            val buffer = ByteArray(2048)
            val deadline = System.nanoTime() + seconds * 1_000_000_000L
            while (System.nanoTime() < deadline) {
                val packet = DatagramPacket(buffer, buffer.size)
                try {
                    video.receive(packet)
                } catch (_: java.net.SocketTimeoutException) {
                    continue
                } catch (_: java.net.SocketException) {
                    break
                }
                if (packet.length < 12 || (buffer[1].toInt() and 0x7f) in 72..76) continue
                buffer[8] = (buffer[8].toInt() xor 0x5a).toByte()
                runCatching { video.send(DatagramPacket(buffer, packet.length, destination, port)) }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun send(text: String) {
        val bytes = text.toByteArray(Charsets.UTF_8)
        sip.send(DatagramPacket(bytes, bytes.size, address, enginePort))
    }

    private fun request(
        method: String,
        target: String,
        callId: String = this.callId,
        toTag: String = remoteTag,
        extra: List<String> = emptyList(),
        contentType: String? = null,
        body: String = "",
        cseq: Int = ++this.cseq,
    ) {
        val to = if (toTag.isEmpty()) "<$engineUri>" else "<$engineUri>;tag=$toTag"
        val lines =
            mutableListOf(
                "$method $target SIP/2.0",
                "Via: SIP/2.0/UDP $host:$port;branch=z9hG4bK${Random.nextLong().toULong().toString(16)};rport",
                "Max-Forwards: 70",
                "From: <$uri>;tag=$tag",
                "To: $to",
                "Call-ID: $callId",
                "CSeq: $cseq $method",
                "Contact: <$uri>",
            )
        lines += extra
        if (contentType != null) lines += "Content-Type: $contentType"
        lines += "Content-Length: ${body.toByteArray(Charsets.UTF_8).size}"
        send(lines.joinToString("\r\n") + "\r\n\r\n" + body)
    }

    fun reply(
        message: SipMessage,
        status: Int,
        reason: String,
        body: String = "",
    ) {
        val to = message.header("To").let { if (it.contains("tag=")) it else "$it;tag=$tag" }
        val lines = message.all("Via").map { "Via: $it" }.toMutableList()
        lines.add(0, "SIP/2.0 $status $reason")
        lines += listOf("From: ${message.header("From")}", "To: $to", "Call-ID: ${message.header("Call-ID")}")
        lines += "CSeq: ${message.header("CSeq")}"
        lines += "Contact: <$uri>"
        if (body.isNotEmpty()) lines += "Content-Type: application/sdp"
        lines += "Content-Length: ${body.toByteArray(Charsets.UTF_8).size}"
        send(lines.joinToString("\r\n") + "\r\n\r\n" + body)
    }

    fun receive(
        seconds: Int,
        accept: (SipMessage) -> Boolean,
    ): SipMessage {
        val deadline = System.nanoTime() + seconds * 1_000_000_000L
        val buffer = ByteArray(65536)
        while (System.nanoTime() < deadline) {
            val packet = DatagramPacket(buffer, buffer.size)
            try {
                sip.receive(packet)
            } catch (_: SocketTimeoutException) {
                continue
            }
            val message = SipMessage.parse(String(packet.data, 0, packet.length, Charsets.UTF_8))
            if (accept(message)) return message
        }
        error("no matching SIP message within $seconds s")
    }

    fun invite(headers: List<String> = emptyList()) {
        request("INVITE", engineUri, extra = headers, contentType = "application/sdp", body = sdp())
    }

    fun awaitFinal(method: String): SipMessage {
        val response = receive(10) { !it.isRequest && it.cseqMethod == method && it.status >= 200 }
        if (method == "INVITE") {
            remoteTag = response.header("To").substringAfter("tag=", "").substringBefore(';')
            remoteTarget =
                response
                    .header("Contact")
                    .substringAfter('<')
                    .substringBefore('>')
                    .ifEmpty { engineUri }
            request("ACK", remoteTarget, cseq = cseq)
        }
        return response
    }

    fun sendRtp(
        answer: SipMessage,
        packets: Int,
    ) {
        val port =
            Regex("m=audio (\\d+)")
                .find(answer.body)
                ?.groupValues
                ?.get(1)
                ?.toInt() ?: error("no audio port")
        val target = Regex("c=IN IP4 ([0-9.]+)").find(answer.body)?.groupValues?.get(1) ?: host
        val destination = InetAddress.getByName(target)
        val ssrc = Random.nextInt()
        Thread {
            for (seq in 0 until packets) {
                val packet = ByteArray(12 + 160) { 0xFF.toByte() }
                packet[0] = 0x80.toByte()
                packet[1] = 0
                packet[2] = (seq shr 8).toByte()
                packet[3] = seq.toByte()
                val timestamp = seq * 160
                for (i in 0 until 4) packet[4 + i] = (timestamp shr (24 - 8 * i)).toByte()
                for (i in 0 until 4) packet[8 + i] = (ssrc shr (24 - 8 * i)).toByte()
                runCatching { rtp.send(DatagramPacket(packet, packet.size, destination, port)) }
                Thread.sleep(20)
            }
        }.apply { isDaemon = true }.start()
    }

    fun info(digit: Char) {
        request(
            "INFO",
            remoteTarget,
            contentType = "application/dtmf-relay",
            body = "Signal=$digit\r\nDuration=160\r\n",
        )
    }

    fun message(text: String) {
        request(
            "MESSAGE",
            engineUri,
            callId = "${Random.nextLong().toULong().toString(16)}@peer",
            toTag = "",
            contentType = "text/plain",
            body = text,
        )
    }

    fun answerInvite(
        direction: String = "sendrecv",
        seconds: Int = 10,
        h264: Boolean = false,
    ): SipMessage {
        val invite = receive(seconds) { it.isRequest && it.method == "INVITE" }
        reply(invite, 180, "Ringing")
        reply(invite, 200, "OK", sdp(direction, h264))
        receive(seconds) { it.isRequest && it.method == "ACK" }
        return invite
    }

    fun rejectInvite(
        status: Int,
        reason: String,
        seconds: Int = 10,
    ): SipMessage {
        val invite = receive(seconds) { it.isRequest && it.method == "INVITE" }
        reply(invite, status, reason)
        receive(seconds) { it.isRequest && it.method == "ACK" }
        return invite
    }

    fun answerRequest(
        method: String,
        seconds: Int = 10,
    ): SipMessage {
        val request = receive(seconds) { it.isRequest && it.method == method }
        reply(request, 200, "OK")
        return request
    }

    override fun close() {
        sip.close()
        rtp.close()
        video.close()
    }
}
