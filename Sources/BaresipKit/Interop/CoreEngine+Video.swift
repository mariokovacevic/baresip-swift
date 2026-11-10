import BaresipKitCore

extension CoreEngine {
    func setVideoSink(_ box: VideoSinkBox?, call: BaresipCallID, local: Bool) throws {
        guard let box else {
            try Self.check { bsk_call_set_video_sink(raw, call.rawValue, local, nil, &$0) }
            return
        }
        var sink = box.makeSink()
        try Self.check { bsk_call_set_video_sink(raw, call.rawValue, local, &sink, &$0) }
    }

    func startPreview(device: String?, box: VideoSinkBox) throws {
        var sink = box.makeSink()
        try Self.withArena { arena in
            try Self.check { bsk_video_preview_start(raw, arena.cString(device), &sink, &$0) }
        }
    }

    func stopPreview() throws {
        try Self.check { bsk_video_preview_stop(raw, &$0) }
    }

    func videoDevices() -> [String] {
        let needed = bsk_video_list_devices(raw, nil, 0)
        guard needed > 0 else { return [] }
        var buffer = [CChar](repeating: 0, count: needed + 1)
        _ = bsk_video_list_devices(raw, &buffer, buffer.count)
        return string(fromNullTerminated: buffer).split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }
}
