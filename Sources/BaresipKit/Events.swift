import Foundation
import BaresipKitCore
import BaresipKitBridge

public enum BaresipEngineState: Int, Sendable, Codable {
    case idle = 0
    case starting = 1
    case ready = 2
    case running = 3
    case stopping = 4
    case stopped = 5
    case failed = 6

    init(_ c: bsk_engine_state) {
        self = BaresipEngineState(rawValue: Int(c.rawValue)) ?? .failed
    }
}

public enum BaresipRegistrationState: Int, Sendable, Codable {
    case none = 0
    case registering = 1
    case registered = 2
    case unregistering = 3
    case failed = 4

    init(_ c: bsk_registration_state) {
        self = BaresipRegistrationState(rawValue: Int(c.rawValue)) ?? .none
    }
}

public enum BaresipCallState: Int, Sendable, Codable {
    case incoming = 0
    case outgoingInit = 1
    case outgoingRinging = 2
    case earlyMedia = 3
    case connected = 4
    case streamsRunning = 5
    case pausing = 6
    case paused = 7
    case resuming = 8
    case pausedByRemote = 9
    case updating = 10
    case ended = 11
    case failed = 12
    case released = 13

    init(_ c: bsk_call_state) {
        self = BaresipCallState(rawValue: Int(c.rawValue)) ?? .failed
    }

    public var isTerminal: Bool {
        self == .ended || self == .failed || self == .released
    }
}

public enum BaresipMediaDirection: Int, Sendable, Codable {
    case inactive = 0
    case sendOnly = 1
    case receiveOnly = 2
    case sendReceive = 3

    init(_ c: bsk_media_direction) {
        self = BaresipMediaDirection(rawValue: Int(c.rawValue)) ?? .inactive
    }

    var c: bsk_media_direction { bsk_media_direction(UInt32(rawValue)) }
}

public enum BaresipMediaEvent: Int, Sendable, Codable {
    case audioStarted = 0
    case audioStopped = 1
    case videoStarted = 2
    case videoStopped = 3
    case remoteHold = 4
    case remoteResume = 5
    case encryptionEstablished = 6
    case rtpTimeout = 7
    case keyframeRequested = 8
    case earlyVideoAvailable = 9

    init(_ c: bsk_media_event) {
        self = BaresipMediaEvent(rawValue: Int(c.rawValue)) ?? .audioStarted
    }
}

public enum BaresipICEState: Int, Sendable, Codable {
    case none = 0
    case gathering = 1
    case checking = 2
    case connected = 3
    case failed = 4

    init(_ c: bsk_ice_state) {
        self = BaresipICEState(rawValue: Int(c.rawValue)) ?? .none
    }
}

public enum BaresipCandidateType: Int, Sendable, Codable {
    case host = 0
    case serverReflexive = 1
    case peerReflexive = 2
    case relay = 3

    init(_ c: bsk_candidate_type) {
        self = BaresipCandidateType(rawValue: Int(c.rawValue)) ?? .host
    }
}

public struct BaresipCallInfo: Sendable, Equatable {
    public let id: BaresipCallID
    public let account: BaresipAccountID
    public let state: BaresipCallState
    public let isOutgoing: Bool
    public let hasVideo: Bool
    public let audioDirection: BaresipMediaDirection
    public let videoDirection: BaresipMediaDirection
    public let sipCallID: String
    public let remoteURI: String
    public let remoteDisplayName: String
    public let audioCodec: String
    public let videoCodec: String
    public let setupTime: Duration
    public let duration: Duration

    init(_ c: bsk_call_info) {
        id = BaresipCallID(rawValue: c.id)
        account = BaresipAccountID(rawValue: c.account)
        state = BaresipCallState(c.state)
        isOutgoing = c.outgoing
        hasVideo = c.has_video
        audioDirection = BaresipMediaDirection(c.audio_dir)
        videoDirection = BaresipMediaDirection(c.video_dir)
        sipCallID = stringFromCArray(c.sip_call_id)
        remoteURI = stringFromCArray(c.remote_uri)
        remoteDisplayName = stringFromCArray(c.remote_display_name)
        audioCodec = stringFromCArray(c.audio_codec)
        videoCodec = stringFromCArray(c.video_codec)
        setupTime = .milliseconds(Int(c.setup_ms))
        duration = .seconds(Int(c.duration_s))
    }
}

public struct BaresipStreamStatistics: Sendable, Equatable {
    public let transmittedPackets: UInt32
    public let receivedPackets: UInt32
    public let transmittedBytes: UInt64
    public let receivedBytes: UInt64
    public let receivedLost: Int32
    public let receivedFractionLostPermille: UInt32
    public let receivedJitter: Duration
    public let roundTripTime: Duration
    public let transmitBitrate: UInt32
    public let receiveBitrate: UInt32
    public let jitterBufferDelay: Duration
    public let isSecure: Bool

    init(_ c: bsk_stream_statistics) {
        transmittedPackets = c.tx_packets
        receivedPackets = c.rx_packets
        transmittedBytes = c.tx_bytes
        receivedBytes = c.rx_bytes
        receivedLost = c.rx_lost
        receivedFractionLostPermille = c.rx_fraction_lost_permille
        receivedJitter = .milliseconds(Int(c.rx_jitter_ms))
        roundTripTime = .milliseconds(Int(c.rtt_ms))
        transmitBitrate = c.tx_bitrate_bps
        receiveBitrate = c.rx_bitrate_bps
        jitterBufferDelay = .milliseconds(Int(c.jitter_buffer_delay_ms))
        isSecure = c.secure
    }
}

public struct BaresipCallStatistics: Sendable, Equatable {
    public let id: BaresipCallID
    public let audio: BaresipStreamStatistics
    public let video: BaresipStreamStatistics
    public let iceState: BaresipICEState
    public let localCandidate: BaresipCandidateType
    public let remoteCandidate: BaresipCandidateType
    public let localAddress: String
    public let remoteAddress: String
    public let mosEstimate: Float
    public let videoTargetBitrate: Int

    init(_ c: bsk_call_statistics) {
        id = BaresipCallID(rawValue: c.id)
        audio = BaresipStreamStatistics(c.audio)
        video = BaresipStreamStatistics(c.video)
        iceState = BaresipICEState(c.ice_state)
        localCandidate = BaresipCandidateType(c.local_candidate)
        remoteCandidate = BaresipCandidateType(c.remote_candidate)
        localAddress = stringFromCArray(c.local_address)
        remoteAddress = stringFromCArray(c.remote_address)
        mosEstimate = c.mos_estimate
        videoTargetBitrate = Int(c.video_target_bitrate_bps)
    }
}

public struct BaresipDTMFEvent: Sendable, Equatable {
    public let digit: Character
    public let isEnd: Bool
    public let viaSIPInfo: Bool
}

public struct BaresipTransferEvent: Sendable, Equatable {
    public let failed: Bool
    public let sipStatus: Int?
    public let targetURI: String
}

public struct BaresipMessage: Sendable, Equatable {
    public let accountID: BaresipAccountID?
    public let from: String
    public let contentType: String
    public let body: Data

    public var text: String? { String(data: body, encoding: .utf8) }
}

public struct BaresipMessageStatus: Sendable, Equatable {
    public let id: BaresipMessageID
    public let delivered: Bool
    public let sipStatus: Int?
    public let error: BaresipError?
}

public struct BaresipICEEvent: Sendable, Equatable {
    public let state: BaresipICEState
    public let localCandidate: BaresipCandidateType
    public let remoteCandidate: BaresipCandidateType
    public let localAddress: String
    public let remoteAddress: String
}

public struct BaresipAudioEvent: Sendable, Equatable {
    public let inputRunning: Bool
    public let outputRunning: Bool
    public let error: BaresipError?
}

public struct BaresipDiagnosticEvent: Sendable, Equatable {
    public let level: BaresipLogLevel
    public let message: String
}

public struct BaresipNetworkEvent: Sendable, Equatable {
    public let transportsReset: Bool
    public let localAddress: String

    public init(transportsReset: Bool, localAddress: String) {
        self.transportsReset = transportsReset
        self.localAddress = localAddress
    }
}

public struct BaresipMediaEventInfo: Sendable, Equatable {
    public let event: BaresipMediaEvent
    public let audioDirection: BaresipMediaDirection
    public let videoDirection: BaresipMediaDirection
    public let detail: String
}

public enum BaresipEvent: Sendable {
    case engine(BaresipEngineState, BaresipError?)
    case registration(BaresipAccountID, BaresipRegistrationState, expires: Duration?, error: BaresipError?)
    case incomingCall(BaresipCallInfo, earlyVideo: Bool)
    case call(BaresipCallID, BaresipCallState, BaresipError?)
    case media(BaresipCallID, BaresipMediaEventInfo)
    case dtmf(BaresipCallID, BaresipDTMFEvent)
    case transfer(BaresipCallID, BaresipTransferEvent)
    case statistics(BaresipCallID, BaresipCallStatistics)
    case ice(BaresipCallID, BaresipICEEvent)
    case network(BaresipNetworkEvent)
    case audio(BaresipCallID?, BaresipAudioEvent)
    case diagnostic(BaresipDiagnosticEvent)
    case message(BaresipMessage)
    case messageStatus(BaresipMessageStatus)

    init?(_ ev: UnsafePointer<bsk_event>) {
        let e = ev.pointee
        let account = BaresipAccountID(rawValue: e.account)
        let call = BaresipCallID(rawValue: e.call)

        func err(_ c: bsk_error) -> BaresipError? {
            c.status == BSK_OK && c.sip_status == 0 ? nil : BaresipError(c)
        }

        switch e.type {
        case BSK_EVENT_ENGINE_STATE:
            let x = bsk_bridge_event_engine(ev)
            self = .engine(BaresipEngineState(x.state), err(x.error))
        case BSK_EVENT_REGISTRATION:
            let x = bsk_bridge_event_registration(ev)
            self = .registration(account, BaresipRegistrationState(x.state),
                                 expires: x.expires == 0 ? nil : .seconds(Int(x.expires)),
                                 error: err(x.error))
        case BSK_EVENT_CALL_STATE:
            let x = bsk_bridge_event_call_state(ev)
            self = .call(call, BaresipCallState(x.state), err(x.error))
        case BSK_EVENT_CALL_INCOMING:
            self = .incomingCall(BaresipCallInfo(bsk_bridge_event_call_incoming(ev)),
                                 earlyVideo: bsk_bridge_event_call_incoming_early_video(ev))
        case BSK_EVENT_CALL_MEDIA:
            let x = bsk_bridge_event_media(ev)
            self = .media(call, BaresipMediaEventInfo(event: BaresipMediaEvent(x.event),
                                                      audioDirection: BaresipMediaDirection(x.audio_dir),
                                                      videoDirection: BaresipMediaDirection(x.video_dir),
                                                      detail: stringFromCArray(x.detail)))
        case BSK_EVENT_CALL_DTMF:
            let x = bsk_bridge_event_dtmf(ev)
            let digit = Character(UnicodeScalar(UInt8(bitPattern: x.digit)))
            self = .dtmf(call, BaresipDTMFEvent(digit: digit, isEnd: x.end, viaSIPInfo: x.via_sip_info))
        case BSK_EVENT_CALL_TRANSFER:
            let x = bsk_bridge_event_transfer(ev)
            self = .transfer(call, BaresipTransferEvent(failed: x.failed,
                                                        sipStatus: x.sip_status == 0 ? nil : Int(x.sip_status),
                                                        targetURI: stringFromCArray(x.target_uri)))
        case BSK_EVENT_CALL_STATISTICS:
            self = .statistics(call, BaresipCallStatistics(bsk_bridge_event_statistics(ev)))
        case BSK_EVENT_ICE:
            let x = bsk_bridge_event_ice(ev)
            self = .ice(call, BaresipICEEvent(state: BaresipICEState(x.state),
                                              localCandidate: BaresipCandidateType(x.local_candidate),
                                              remoteCandidate: BaresipCandidateType(x.remote_candidate),
                                              localAddress: stringFromCArray(x.local_address),
                                              remoteAddress: stringFromCArray(x.remote_address)))
        case BSK_EVENT_NETWORK:
            let x = bsk_bridge_event_network(ev)
            self = .network(BaresipNetworkEvent(transportsReset: x.transports_reset,
                                                localAddress: stringFromCArray(x.local_address)))
        case BSK_EVENT_AUDIO:
            let x = bsk_bridge_event_audio(ev)
            self = .audio(e.call == 0 ? nil : call,
                          BaresipAudioEvent(inputRunning: x.input_running, outputRunning: x.output_running,
                                            error: err(x.error)))
        case BSK_EVENT_DIAGNOSTIC:
            let x = bsk_bridge_event_diagnostic(ev)
            self = .diagnostic(BaresipDiagnosticEvent(level: BaresipLogLevel(x.level),
                                                      message: stringFromCArray(x.message)))
        case BSK_EVENT_MESSAGE:
            let x = bsk_bridge_event_message(ev)
            let body = x.body.map { Data(bytes: $0, count: x.body_len) } ?? Data()
            self = .message(BaresipMessage(accountID: e.account == 0 ? nil : account,
                                           from: stringFromCArray(x.from),
                                           contentType: stringFromCArray(x.content_type),
                                           body: body))
        case BSK_EVENT_MESSAGE_STATUS:
            let x = bsk_bridge_event_message_status(ev)
            self = .messageStatus(BaresipMessageStatus(id: BaresipMessageID(rawValue: x.message_id),
                                                       delivered: x.delivered,
                                                       sipStatus: x.sip_status == 0 ? nil : Int(x.sip_status),
                                                       error: err(x.error)))
        default:
            return nil
        }
    }
}
