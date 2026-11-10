import Foundation
import BaresipKitCore
import BaresipKitBridge

extension BaresipEvent {
    init?(_ pointer: UnsafePointer<bsk_event>) {
        let header = pointer.pointee
        let account = BaresipAccountID(rawValue: header.account)
        let call = BaresipCallID(rawValue: header.call)

        switch header.type {
        case BSK_EVENT_ENGINE_STATE:
            let payload = bsk_bridge_event_engine(pointer)
            self = .engine(BaresipEngineState(payload.state), .optional(payload.error))
        case BSK_EVENT_REGISTRATION:
            let payload = bsk_bridge_event_registration(pointer)
            self = .registration(account, BaresipRegistrationState(payload.state),
                                 expires: payload.expires == 0 ? nil : .seconds(Int(payload.expires)),
                                 error: .optional(payload.error))
        case BSK_EVENT_CALL_STATE:
            let payload = bsk_bridge_event_call_state(pointer)
            self = .call(call, BaresipCallState(payload.state), .optional(payload.error))
        case BSK_EVENT_CALL_INCOMING:
            self = .incomingCall(BaresipCallInfo(bsk_bridge_event_call_incoming(pointer)),
                                 earlyVideo: bsk_bridge_event_call_incoming_early_video(pointer))
        case BSK_EVENT_CALL_MEDIA:
            self = .media(call, Self.mediaInfo(bsk_bridge_event_media(pointer)))
        case BSK_EVENT_CALL_DTMF:
            self = .dtmf(call, Self.dtmf(bsk_bridge_event_dtmf(pointer)))
        case BSK_EVENT_CALL_TRANSFER:
            self = .transfer(call, Self.transfer(bsk_bridge_event_transfer(pointer)))
        case BSK_EVENT_CALL_STATISTICS:
            self = .statistics(call, BaresipCallStatistics(bsk_bridge_event_statistics(pointer)))
        case BSK_EVENT_ICE:
            self = .ice(call, Self.ice(bsk_bridge_event_ice(pointer)))
        case BSK_EVENT_NETWORK:
            let payload = bsk_bridge_event_network(pointer)
            self = .network(BaresipNetworkEvent(transportsReset: payload.transports_reset,
                                                localAddress: string(fromCArray: payload.local_address)))
        case BSK_EVENT_AUDIO:
            let payload = bsk_bridge_event_audio(pointer)
            self = .audio(header.call == 0 ? nil : call,
                          BaresipAudioEvent(inputRunning: payload.input_running,
                                            outputRunning: payload.output_running,
                                            error: .optional(payload.error)))
        case BSK_EVENT_DIAGNOSTIC:
            let payload = bsk_bridge_event_diagnostic(pointer)
            self = .diagnostic(BaresipDiagnosticEvent(level: BaresipLogLevel(payload.level),
                                                      message: string(fromCArray: payload.message)))
        case BSK_EVENT_MESSAGE:
            self = .message(Self.message(bsk_bridge_event_message(pointer),
                                         account: header.account == 0 ? nil : account))
        case BSK_EVENT_MESSAGE_STATUS:
            self = .messageStatus(Self.messageStatus(bsk_bridge_event_message_status(pointer)))
        default:
            return nil
        }
    }

    private static func mediaInfo(_ payload: bsk_bridge_media_event) -> BaresipMediaEventInfo {
        BaresipMediaEventInfo(event: BaresipMediaEvent(payload.event),
                              audioDirection: BaresipMediaDirection(payload.audio_dir),
                              videoDirection: BaresipMediaDirection(payload.video_dir),
                              detail: string(fromCArray: payload.detail))
    }

    private static func dtmf(_ payload: bsk_bridge_dtmf_event) -> BaresipDTMFEvent {
        let digit = Character(UnicodeScalar(UInt8(bitPattern: payload.digit)))
        return BaresipDTMFEvent(digit: digit, isEnd: payload.end, viaSIPInfo: payload.via_sip_info)
    }

    private static func transfer(_ payload: bsk_bridge_transfer_event) -> BaresipTransferEvent {
        BaresipTransferEvent(failed: payload.failed,
                             sipStatus: payload.sip_status == 0 ? nil : Int(payload.sip_status),
                             targetURI: string(fromCArray: payload.target_uri))
    }

    private static func ice(_ payload: bsk_bridge_ice_event) -> BaresipICEEvent {
        BaresipICEEvent(state: BaresipICEState(payload.state),
                        localCandidate: BaresipCandidateType(payload.local_candidate),
                        remoteCandidate: BaresipCandidateType(payload.remote_candidate),
                        localAddress: string(fromCArray: payload.local_address),
                        remoteAddress: string(fromCArray: payload.remote_address))
    }

    private static func message(_ payload: bsk_bridge_message_event, account: BaresipAccountID?) -> BaresipMessage {
        // SAFETY: body points at body_len bytes owned by the event, which outlives this call.
        let body = payload.body.map { Data(bytes: $0, count: payload.body_len) } ?? Data()
        return BaresipMessage(accountID: account,
                              from: string(fromCArray: payload.from),
                              contentType: string(fromCArray: payload.content_type),
                              body: body)
    }

    private static func messageStatus(_ payload: bsk_bridge_message_status_event) -> BaresipMessageStatus {
        BaresipMessageStatus(id: BaresipMessageID(rawValue: payload.message_id),
                             delivered: payload.delivered,
                             sipStatus: payload.sip_status == 0 ? nil : Int(payload.sip_status),
                             error: .optional(payload.error))
    }
}
