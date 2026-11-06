extension BaresipEngine {
    /// Attaches a renderer to a call's remote or local video, or detaches it.
    ///
    /// The engine keeps a strong reference to the renderer until it is replaced, detached
    /// or the call is released.
    ///
    /// - Parameters:
    ///   - renderer: The renderer, or `nil` to detach.
    ///   - callID: The call.
    ///   - local: `true` for the camera image sent to the peer, `false` for the remote video.
    /// - Throws: ``BaresipError`` for an unknown call.
    public func setVideoRenderer(_ renderer: BaresipVideoRenderer?, callID: BaresipCallID,
                                 local: Bool = false) async throws {
        let key = VideoSinkKey(callID: callID, local: local)
        let box = renderer.map { VideoSinkBox(renderer: $0, callID: callID, local: local) }
        try await replaceSink(key, with: box) { try $0.setVideoSink(box, call: callID, local: local) }
    }

    /// Starts the camera outside a call and sends its frames to a renderer.
    ///
    /// - Parameters:
    ///   - device: A device name from ``videoDevices()``, or `nil` for the default camera.
    ///   - renderer: The renderer.
    /// - Throws: ``BaresipError`` when the camera cannot be opened.
    public func startVideoPreview(device: String? = nil, renderer: BaresipVideoRenderer) async throws {
        let key = VideoSinkKey(callID: nil, local: true)
        let box = VideoSinkBox(renderer: renderer, callID: nil, local: true)
        try await replaceSink(key, with: box) { try $0.startPreview(device: device, box: box) }
    }

    /// Stops the camera preview.
    ///
    /// - Throws: ``BaresipError`` when the core cannot stop the preview.
    public func stopVideoPreview() async throws {
        try await run { try $0.stopPreview() }
        let previous = lock.withLock { videoSinks.removeValue(forKey: VideoSinkKey(callID: nil, local: true)) }
        withExtendedLifetime(previous) {}
    }

    /// The names of the available cameras.
    ///
    /// - Returns: Device names for ``setCamera(_:callID:)`` and ``startVideoPreview(device:renderer:)``.
    public func videoDevices() async -> [String] {
        await (try? run { $0.videoDevices() }) ?? []
    }

    func clearVideoSinks(callID: BaresipCallID) {
        let removed = lock.withLock {
            [true, false].compactMap { videoSinks.removeValue(forKey: VideoSinkKey(callID: callID, local: $0)) }
        }
        withExtendedLifetime(removed) {}
    }

    private func replaceSink(_ key: VideoSinkKey, with box: VideoSinkBox?,
                             install: @escaping @Sendable (CoreEngine) throws -> Void) async throws {
        let previous = lock.withLock { () -> VideoSinkBox? in
            let old = videoSinks[key]
            videoSinks[key] = box
            return old
        }
        do {
            try await run(install)
        } catch {
            lock.withLock {
                if videoSinks[key] === box {
                    videoSinks[key] = previous
                }
            }
            throw error
        }
        withExtendedLifetime(previous) {}
    }
}
