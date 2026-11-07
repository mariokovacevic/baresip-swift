import BaresipKitCore

final class VideoSinkBox: Sendable {
    let renderer: BaresipVideoRenderer
    let callID: BaresipCallID?
    let local: Bool

    init(renderer: BaresipVideoRenderer, callID: BaresipCallID?, local: Bool) {
        self.renderer = renderer
        self.callID = callID
        self.local = local
    }

    func makeSink() -> bsk_video_sink {
        var sink = bsk_video_sink()
        // SAFETY: BaresipEngine keeps this box in videoSinks until the core has dropped the sink
        // (sink replaced, call released or preview stopped), so the unretained pointer stays valid.
        sink.user = Unmanaged.passUnretained(self).toOpaque()
        sink.on_frame = { _, _, _, frame, user in
            guard let user, let frame else { return }
            let box = Unmanaged<VideoSinkBox>.fromOpaque(user).takeUnretainedValue()
            guard let videoFrame = BaresipVideoFrame(frame.pointee) else { return }
            box.renderer.render(videoFrame)
        }
        sink.on_size = { _, _, _, width, height, user in
            guard let user else { return }
            let box = Unmanaged<VideoSinkBox>.fromOpaque(user).takeUnretainedValue()
            box.renderer.didChangeSize(width: Int(width), height: Int(height))
        }
        return sink
    }
}

struct VideoSinkKey: Hashable, Sendable {
    let callID: BaresipCallID?
    let local: Bool
}
