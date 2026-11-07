import BaresipKitCore

extension CoreEngine {
    func setMicrophoneMuted(_ call: BaresipCallID, _ muted: Bool) throws {
        try Self.check { bsk_call_set_microphone_muted(raw, call.rawValue, muted, &$0) }
    }

    func setAudioDirection(_ call: BaresipCallID, _ direction: BaresipMediaDirection) throws {
        try Self.check { bsk_call_set_audio_direction(raw, call.rawValue, direction.core, &$0) }
    }

    func setVideoDirection(_ call: BaresipCallID, _ direction: BaresipMediaDirection) throws {
        try Self.check { bsk_call_set_video_direction(raw, call.rawValue, direction.core, &$0) }
    }

    func setCamera(_ call: BaresipCallID, device: String) throws {
        try Self.withArena { arena in
            try Self.check { bsk_call_set_camera(raw, call.rawValue, arena.cString(device), &$0) }
        }
    }

    func requestKeyframe(_ call: BaresipCallID) throws {
        try Self.check { bsk_call_request_keyframe(raw, call.rawValue, &$0) }
    }

    func setVideoMaxBitrate(_ call: BaresipCallID, bitsPerSecond: UInt32) throws {
        try Self.check { bsk_call_set_video_max_bitrate(raw, call.rawValue, bitsPerSecond, &$0) }
    }

    func restartICE(_ call: BaresipCallID) throws {
        try Self.check { bsk_call_restart_ice(raw, call.rawValue, &$0) }
    }

    func startRecording(_ call: BaresipCallID, path: String) throws {
        try Self.withArena { arena in
            try Self.check { bsk_call_record_start(raw, call.rawValue, arena.cString(path), &$0) }
        }
    }

    func stopRecording(_ call: BaresipCallID) throws {
        try Self.check { bsk_call_record_stop(raw, call.rawValue, &$0) }
    }

    func sendMessage(account: BaresipAccountID?, to peer: String, text: String) throws -> BaresipMessageID {
        var id: UInt64 = 0
        try Self.withArena { arena in
            try Self.check {
                bsk_message_send(raw, account?.rawValue ?? 0, arena.cString(peer), arena.cString(text), &id, &$0)
            }
        }
        return BaresipMessageID(rawValue: id)
    }
}
