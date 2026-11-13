package io.github.mariokovacevic.baresipkit.zvono.model

import io.github.mariokovacevic.baresipkit.BaresipCallState
import io.github.mariokovacevic.baresipkit.BaresipRegistrationState
import kotlin.time.Duration.Companion.seconds
import kotlin.time.TimeSource

const val DEMO_HOST = "pbx.example.com"

fun CallModel.seedDemo() {
    demoMode = true
    replaceSettings(SipSettings(domain = DEMO_HOST, username = "alice", reachableInBackground = true))
    password = "secret"
    registration = BaresipRegistrationState.REGISTERED
    val front = "sip:frontdoor@$DEMO_HOST"
    val gate = "sip:gate@$DEMO_HOST"
    val reception = "sip:reception@$DEMO_HOST"
    doors =
        listOf(
            Door(id = "demo-front", name = "Front door", address = front, code = "1234"),
            Door(id = "demo-gate", name = "Garage gate", address = gate, code = "4711", hasCamera = false),
        )
    contacts =
        listOf(
            Contact(id = "demo-reception", name = "Reception", address = "reception"),
            Contact(id = "demo-caretaker", name = "Caretaker", address = "caretaker"),
        )
    val now = System.currentTimeMillis()
    history =
        listOf(
            CallRecord(uri = front, name = "Front door", outgoing = false, startedAt = now - 600_000),
            CallRecord(uri = gate, name = "gate", outgoing = true, startedAt = now - 2_400_000, durationSeconds = 6.0, dtmf = "4711", dtmfResult = "sent"),
            CallRecord(
                uri = front,
                name = "Front door",
                outgoing = false,
                startedAt = now - 3_600_000,
                durationSeconds = 18.0,
                dtmf = "1234",
                dtmfResult = "sent",
            ),
            CallRecord(uri = reception, name = "Reception", outgoing = true, video = true, startedAt = now - 90_000_000, durationSeconds = 130.0),
        )
    messages.clear()
    messages +=
        listOf(
            ChatMessage(
                peer = reception,
                text = "Good morning. A parcel is waiting for you at the desk.",
                outgoing = false,
                status = ChatStatus.Received,
                date = now - 1_500_000,
                read = false,
            ),
            ChatMessage(
                peer = reception,
                text = "Thank you. I will pick it up after six.",
                outgoing = true,
                status = ChatStatus.Delivered,
                date = now - 1_400_000,
            ),
            ChatMessage(
                peer = reception,
                text = "The desk closes at eight today.",
                outgoing = false,
                status = ChatStatus.Received,
                date = now - 1_300_000,
                read = false,
            ),
            ChatMessage(
                peer = reception,
                text = "He should be there in ten minutes.",
                outgoing = true,
                status = ChatStatus.Failed("408 Request Timeout"),
                date = now - 1_200_000,
            ),
        )
}

fun CallModel.demoRing(address: String = "sip:frontdoor@$DEMO_HOST") {
    demoIncoming =
        CallRow(
            id = null,
            remoteUri = address,
            remoteName = "",
            state = BaresipCallState.INCOMING,
            outgoing = false,
            hasVideo = true,
            receivingVideo = true,
            startedAt = TimeSource.Monotonic.markNow() - 4.seconds,
        )
    previewing = false
    previewVideo = false
}

fun CallModel.startDemoCall(
    target: String,
    video: Boolean,
) {
    demoCall =
        CallRow(
            id = null,
            remoteUri = target,
            remoteName = "",
            state = BaresipCallState.STREAMS_RUNNING,
            outgoing = true,
            hasVideo = true,
            receivingVideo = true,
            sendingVideo = video,
            codec = "opus/48000/2",
            startedAt = TimeSource.Monotonic.markNow() - 12.seconds,
            connectedAt = TimeSource.Monotonic.markNow() - 9.seconds,
        )
    demoDoorOpened = false
    callMinimized = false
    pendingDtmf = null
}

fun CallModel.answerDemo() {
    val ringing = demoIncoming ?: return
    demoIncoming = null
    previewing = false
    previewVideo = false
    demoCall = ringing.copy(state = BaresipCallState.STREAMS_RUNNING, connectedAt = TimeSource.Monotonic.markNow(), codec = "opus/48000/2")
    demoDoorOpened = false
    callMinimized = false
}

fun CallModel.endDemoCall() {
    val ended = demoCall ?: return
    demoCall = null
    captions = emptyList()
    showCallChat = null
    recordHistory(ended.copy(state = BaresipCallState.ENDED), null)
}

fun CallModel.demoMessage(text: String) {
    val call = demoCall ?: return
    messages += ChatMessage(peer = call.remoteUri, text = text, outgoing = false, status = ChatStatus.Received, read = false)
    if (showCallChat == null && !callMinimized) showCaption(doorFor(call.remoteUri)?.title ?: call.title, text)
}
