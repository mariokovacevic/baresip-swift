import BaresipKitCore

extension BaresipError {
    init(_ error: bsk_error) {
        self.init(code: BaresipError.Code(error.status),
                  systemErrno: error.sys_errno,
                  sipStatus: error.sip_status == 0 ? nil : Int(error.sip_status),
                  sipReason: string(fromCArray: error.sip_reason),
                  message: string(fromCArray: error.message))
    }

    init(status: bsk_status, _ error: bsk_error) {
        var copy = error
        if copy.status == BSK_OK {
            copy.status = status
        }
        self.init(copy)
    }

    init(_ error: bsk_error, endReason: bsk_call_end_reason) {
        self.init(code: BaresipError.Code(error.status),
                  systemErrno: error.sys_errno,
                  sipStatus: error.sip_status == 0 ? nil : Int(error.sip_status),
                  sipReason: string(fromCArray: error.sip_reason),
                  message: string(fromCArray: error.message),
                  endReason: BaresipCallEndReason(endReason))
    }

    static func optional(_ error: bsk_error) -> BaresipError? {
        error.status == BSK_OK && error.sip_status == 0 ? nil : BaresipError(error)
    }

    static func optional(_ error: bsk_error, endReason: bsk_call_end_reason) -> BaresipError? {
        guard error.status != BSK_OK || error.sip_status != 0 || endReason != BSK_END_NORMAL else { return nil }
        return BaresipError(error, endReason: endReason)
    }
}

extension BaresipCallEndReason {
    init?(_ reason: bsk_call_end_reason) {
        switch reason {
        case BSK_END_ANSWERED_ELSEWHERE: self = .answeredElsewhere
        case BSK_END_DECLINED_ELSEWHERE: self = .declinedElsewhere
        default: return nil
        }
    }
}

extension BaresipCallInfo {
    init(_ info: bsk_call_info) {
        self.init(id: BaresipCallID(rawValue: info.id),
                  account: BaresipAccountID(rawValue: info.account),
                  state: BaresipCallState(info.state),
                  isOutgoing: info.outgoing,
                  hasVideo: info.has_video,
                  audioDirection: BaresipMediaDirection(info.audio_dir),
                  videoDirection: BaresipMediaDirection(info.video_dir),
                  sipCallID: string(fromCArray: info.sip_call_id),
                  remoteURI: string(fromCArray: info.remote_uri),
                  remoteDisplayName: string(fromCArray: info.remote_display_name),
                  audioCodec: string(fromCArray: info.audio_codec),
                  videoCodec: string(fromCArray: info.video_codec),
                  setupTime: .milliseconds(Int(info.setup_ms)),
                  duration: .seconds(Int(info.duration_s)),
                  isMicrophoneMuted: info.microphone_muted)
    }
}

extension BaresipStreamStatistics {
    init(_ stats: bsk_stream_statistics) {
        self.init(transmittedPackets: stats.tx_packets,
                  receivedPackets: stats.rx_packets,
                  transmittedBytes: stats.tx_bytes,
                  receivedBytes: stats.rx_bytes,
                  receivedLost: stats.rx_lost,
                  receivedFractionLostPermille: stats.rx_fraction_lost_permille,
                  receivedJitter: .milliseconds(Int(stats.rx_jitter_ms)),
                  roundTripTime: .milliseconds(Int(stats.rtt_ms)),
                  transmitBitrate: stats.tx_bitrate_bps,
                  receiveBitrate: stats.rx_bitrate_bps,
                  jitterBufferDelay: .milliseconds(Int(stats.jitter_buffer_delay_ms)),
                  isSecure: stats.secure)
    }
}

extension BaresipCallStatistics {
    init(_ stats: bsk_call_statistics) {
        self.init(id: BaresipCallID(rawValue: stats.id),
                  audio: BaresipStreamStatistics(stats.audio),
                  video: BaresipStreamStatistics(stats.video),
                  iceState: BaresipICEState(stats.ice_state),
                  localCandidate: BaresipCandidateType(stats.local_candidate),
                  remoteCandidate: BaresipCandidateType(stats.remote_candidate),
                  localAddress: string(fromCArray: stats.local_address),
                  remoteAddress: string(fromCArray: stats.remote_address),
                  mosEstimate: stats.mos_estimate,
                  videoTargetBitrate: Int(stats.video_target_bitrate_bps))
    }
}
