import Foundation
import BaresipKitCore

private struct EngineHandle: @unchecked Sendable {
    let raw: OpaquePointer
}

public final class BaresipEngine: @unchecked Sendable {
    private let handle: OpaquePointer
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<BaresipEvent>.Continuation] = [:]
    private var logHandler: BaresipLogHandler?
    private let workQueue = DispatchQueue(label: "baresipkit.engine", qos: .userInitiated)
    private var defaultAccount: BaresipAccountID?
    private var videoSinks: [VideoSinkKey: VideoSinkBox] = [:]

    public let configuration: BaresipConfiguration

    public init(configuration: BaresipConfiguration) throws {
        self.configuration = configuration
        let arena = CStringArena()
        var cfg = bsk_engine_config()
        cfg.size = UInt32(MemoryLayout<bsk_engine_config>.size)
        cfg.user_agent = arena.cString(configuration.userAgent)
        cfg.instance_uuid = arena.cString(configuration.instanceUUID.uuidString.lowercased())
        cfg.network_interface = arena.cString(configuration.networkInterface)
        cfg.modules = arena.cStringArray(configuration.modules)
        cfg.module_count = configuration.modules.count
        cfg.extra_config = arena.cString(configuration.extraConfiguration)
        cfg.ipv6 = configuration.ipv6
        cfg.rtp_port_min = configuration.rtpPortRange.lowerBound
        cfg.rtp_port_max = configuration.rtpPortRange.upperBound
        cfg.max_calls = UInt32(configuration.maxCalls)
        cfg.log_level = configuration.logLevel.c
        cfg.log_sip_trace = configuration.logSIPTrace
        cfg.ice_relay_only = configuration.iceRelayOnly
        cfg.video_adaptive_bitrate = configuration.videoAdaptiveBitrate
        cfg.video_min_bitrate_bps = UInt32(clamping: max(0, configuration.videoMinimumBitrate))

        let a = configuration.audio
        cfg.audio.source_module = arena.cString(a.sourceModule)
        cfg.audio.source_device = arena.cString(a.sourceDevice)
        cfg.audio.player_module = arena.cString(a.playerModule)
        cfg.audio.player_device = arena.cString(a.playerDevice)
        cfg.audio.sample_rate = UInt32(a.sampleRate ?? 0)
        cfg.audio.channels = UInt32(a.channels ?? 0)
        cfg.audio.ptime_ms = a.packetTime.wholeMilliseconds
        cfg.audio.jitter_buffer_min_ms = UInt32(a.jitterBufferRange.lowerBound)
        cfg.audio.jitter_buffer_max_ms = UInt32(a.jitterBufferRange.upperBound)
        cfg.audio.jitter_buffer_adaptive = a.adaptiveJitterBuffer
        cfg.audio.voice_processing = a.voiceProcessing
        cfg.audio.codecs = arena.cStringArray(a.codecs)
        cfg.audio.codec_count = a.codecs.count

        let v = configuration.video
        cfg.video.source_module = arena.cString(v.sourceModule)
        cfg.video.source_device = arena.cString(v.sourceDevice)
        cfg.video.width = UInt32(v.width)
        cfg.video.height = UInt32(v.height)
        cfg.video.fps = UInt32(v.framesPerSecond)
        cfg.video.bitrate_bps = UInt32(v.bitrate)
        cfg.video.codecs = arena.cStringArray(v.codecs)
        cfg.video.codec_count = v.codecs.count
        cfg.video.hardware_acceleration = v.hardwareAcceleration

        let t = configuration.tls
        let ca = arena.bytes(t.caCertificatesPEM)
        cfg.tls.ca_pem = ca.0
        cfg.tls.ca_pem_len = ca.1
        let cert = arena.bytes(t.clientCertificatePEM)
        cfg.tls.client_cert_pem = cert.0
        cfg.tls.client_cert_pem_len = cert.1
        cfg.tls.pinned_spki_sha256_base64 = arena.cStringArray(t.pinnedSPKISHA256)
        cfg.tls.pinned_count = t.pinnedSPKISHA256.count
        cfg.tls.cipher_list = arena.cString(t.cipherList)
        cfg.tls.min_version = Int32(t.minimumVersion.rawValue)
        cfg.tls.verify_server = t.verifyServer

        var err = bsk_error()
        var created: OpaquePointer?
        let status = bsk_engine_create(&cfg, nil, nil, &created, &err)
        guard status == BSK_OK, let created else {
            throw BaresipError(status: status, err)
        }
        handle = created
        withExtendedLifetime(arena) {}

        installCallbacks()
    }

    deinit {
        bsk_engine_set_event_handler(handle, nil, nil)
        bsk_engine_set_log_handler(handle, nil, nil)
        bsk_engine_destroy(handle)
        lock.lock()
        let conts = continuations.values
        continuations.removeAll()
        lock.unlock()
        for c in conts {
            c.finish()
        }
    }

    private func installCallbacks() {
        let user = Unmanaged.passUnretained(self).toOpaque()
        bsk_engine_set_event_handler(handle, { _, event, user in
            guard let user, let event else { return }
            Unmanaged<BaresipEngine>.fromOpaque(user).takeUnretainedValue().deliver(event)
        }, user)
        bsk_engine_set_log_handler(handle, { level, domain, line, len, user in
            guard let user, let line else { return }
            let engine = Unmanaged<BaresipEngine>.fromOpaque(user).takeUnretainedValue()
            let text = String(decoding: UnsafeRawBufferPointer(start: line, count: len), as: UTF8.self)
            engine.deliverLog(BaresipLogEntry(level: BaresipLogLevel(level),
                                              domain: BaresipLogDomain(domain),
                                              message: text))
        }, user)
    }

    private func deliverLog(_ entry: BaresipLogEntry) {
        lock.lock()
        let handler = logHandler
        lock.unlock()
        handler?(entry)
    }

    fileprivate func deliver(_ ev: UnsafePointer<bsk_event>) {
        guard let event = BaresipEvent(ev) else { return }
        if case .call(let callID, .released, _) = event {
            clearVideoSinks(callID: callID)
        }
        lock.lock()
        let conts = Array(continuations.values)
        lock.unlock()
        for c in conts {
            c.yield(event)
        }
    }

    public var events: AsyncStream<BaresipEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations[id] = nil
                self.lock.unlock()
            }
        }
    }

    public func setLogHandler(_ handler: BaresipLogHandler?) {
        lock.lock()
        logHandler = handler
        lock.unlock()
    }

    public var state: BaresipEngineState {
        BaresipEngineState(bsk_engine_get_state(handle))
    }

    private func run<T: Sendable>(_ body: @escaping @Sendable (OpaquePointer) throws -> T) async throws -> T {
        let handle = EngineHandle(raw: self.handle)
        return try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                do {
                    continuation.resume(returning: try body(handle.raw))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func check(_ status: bsk_status, _ err: bsk_error) throws {
        if status != BSK_OK {
            throw BaresipError(status: status, err)
        }
    }

    public func start() async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_start(h, &err), err)
        }
    }

    public func stop(timeout: Duration = .seconds(3)) async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_stop(h, timeout.wholeMilliseconds, &err), err)
        }
    }

    public func prepareForPushWakeUp() async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_prepare_for_push_wakeup(h, &err), err)
        }
    }

    public func suspend() async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_suspend(h, &err), err)
        }
    }

    public func resume() async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_resume(h, &err), err)
        }
    }

    public func networkDidChange(reregister: Bool = true, updateCalls: Bool = true) async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_network_changed(h, reregister, updateCalls, &err), err)
        }
    }

    public func audioSessionDidActivate() async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_audio_session_activated(h, &err), err)
        }
    }

    public func audioSessionDidDeactivate() async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_audio_session_deactivated(h, &err), err)
        }
    }

    public func audioRouteDidChange() async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_audio_route_changed(h, &err), err)
        }
    }

    public func audioInterruption(began: Bool) async {
        _ = try? await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_engine_audio_interruption(h, began, &err), err)
        }
    }

    public func addAccount(_ account: BaresipAccountConfiguration) async throws -> BaresipAccountID {
        try account.validate()
        let id: UInt64 = try await run { h in
            let arena = CStringArena()
            var cfg = bsk_account_config()
            cfg.size = UInt32(MemoryLayout<bsk_account_config>.size)
            cfg.aor = arena.cString(account.aor)
            cfg.display_name = arena.cString(account.displayName)
            cfg.registrar = arena.cString(account.registrar)
            cfg.outbound_proxy = arena.cString(account.outboundProxy)
            cfg.transport = account.transport.c
            cfg.auth_user = arena.cString(account.authUser)
            cfg.auth_password = arena.cString(account.authPassword)
            cfg.register_expires = account.registerExpires.wholeSeconds
            cfg.register_retry_min_s = account.registerRetry.lowerBound.wholeSeconds
            cfg.register_retry_max_s = account.registerRetry.upperBound.wholeSeconds
            cfg.sip_outbound = account.sipOutbound
            cfg.keepalive = account.keepAlive
            cfg.media_encryption = account.mediaEncryption.c
            cfg.nat.mode = account.nat.mode.c
            cfg.nat.stun_uri = arena.cString(account.nat.stunURI)
            cfg.nat.turn_servers = arena.turnServers(account.nat.turnServers)
            cfg.nat.turn_count = account.nat.turnServers.count
            cfg.nat.symmetric_rtp_latching = account.nat.symmetricRTPLatching
            cfg.nat.rtp_timeout_ms = account.nat.rtpTimeout.wholeMilliseconds
            cfg.dtmf_mode = account.dtmfMode.c
            cfg.contact_params = arena.contactParams(account.contactParameters)
            cfg.contact_param_count = account.contactParameters.count
            cfg.audio_codecs = arena.cStringArray(account.audioCodecs)
            cfg.audio_codec_count = account.audioCodecs.count
            cfg.video_codecs = arena.cStringArray(account.videoCodecs)
            cfg.video_codec_count = account.videoCodecs.count
            cfg.answer_early_media = account.answerEarlyMedia

            var id: UInt64 = 0
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_add(h, &cfg, &id, &err), err)
            withExtendedLifetime(arena) {}
            return id
        }
        let accountID = BaresipAccountID(rawValue: id)
        lock.withLock {
            if defaultAccount == nil {
                defaultAccount = accountID
            }
        }
        return accountID
    }

    func clearVideoSinks(callID: BaresipCallID) {
        let removed = lock.withLock { () -> [VideoSinkBox] in
            var out: [VideoSinkBox] = []
            for local in [true, false] {
                if let box = videoSinks.removeValue(forKey: VideoSinkKey(callID: callID, local: local)) {
                    out.append(box)
                }
            }
            return out
        }
        withExtendedLifetime(removed) {}
    }

    public func removeAccount(_ id: BaresipAccountID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_remove(h, id.rawValue, &err), err)
        }
        lock.withLock {
            if defaultAccount == id {
                defaultAccount = nil
            }
        }
    }

    public func setDefaultAccount(_ id: BaresipAccountID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_set_default(h, id.rawValue, &err), err)
        }
        lock.withLock {
            defaultAccount = id
        }
    }

    public func register(accountID: BaresipAccountID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_register(h, accountID.rawValue, &err), err)
        }
    }

    public func unregister(accountID: BaresipAccountID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_unregister(h, accountID.rawValue, &err), err)
        }
    }

    public func updateCredentials(accountID: BaresipAccountID, authUser: String?, password: String) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_set_credentials(h, accountID.rawValue,
                                                                arena.cString(authUser),
                                                                arena.cString(password), &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func updateContactParameters(accountID: BaresipAccountID, parameters: [ContactParameter],
                                        reregisterNow: Bool = true) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_account_set_contact_params(h, accountID.rawValue,
                                                                   arena.contactParams(parameters),
                                                                   parameters.count, reregisterNow,
                                                                   &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func registrationState(accountID: BaresipAccountID) -> BaresipRegistrationState {
        var state = BSK_REG_NONE
        _ = bsk_account_get_registration_state(handle, accountID.rawValue, &state)
        return BaresipRegistrationState(state)
    }

    public static func encodeContactParameters(_ parameters: [ContactParameter]) throws -> String {
        let arena = CStringArena()
        let params = arena.contactParams(parameters)
        var needed = 0
        let probe = bsk_contact_params_encode(params, parameters.count, nil, 0, &needed)
        guard probe == BSK_OK else {
            throw BaresipError(status: BaresipStatus(probe), message: "invalid contact parameters")
        }
        var buffer = [CChar](repeating: 0, count: needed + 1)
        let status = bsk_contact_params_encode(params, parameters.count, &buffer, buffer.count, nil)
        guard status == BSK_OK else {
            throw BaresipError(status: BaresipStatus(status), message: "invalid contact parameters")
        }
        withExtendedLifetime(arena) {}
        return String(cString: buffer)
    }

    public func makeCall(accountID: BaresipAccountID? = nil, destination: String,
                         video: Bool = false) async throws -> BaresipCallID {
        let account = lock.withLock { accountID ?? defaultAccount }
        let id: UInt64 = try await run { h in
            let arena = CStringArena()
            var id: UInt64 = 0
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_make(h, account?.rawValue ?? 0,
                                                  arena.cString(destination), video, &id, &err), err)
            withExtendedLifetime(arena) {}
            return id
        }
        return BaresipCallID(rawValue: id)
    }

    public func answer(callID: BaresipCallID, video: Bool = false) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_answer(h, callID.rawValue, video, &err), err)
        }
    }

    public func sendProgress(callID: BaresipCallID, earlyVideo: Bool = false) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_progress(h, callID.rawValue, earlyVideo, &err), err)
        }
    }

    public func reject(callID: BaresipCallID, statusCode: Int = 486, reason: String? = nil) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_reject(h, callID.rawValue, UInt16(statusCode),
                                                    arena.cString(reason), &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func hangup(callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_hangup(h, callID.rawValue, &err), err)
        }
    }

    public func hold(callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_hold(h, callID.rawValue, true, &err), err)
        }
    }

    public func resume(callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_hold(h, callID.rawValue, false, &err), err)
        }
    }

    public func setActiveCall(_ callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_active(h, callID.rawValue, &err), err)
        }
    }

    public func sendDTMF(callID: BaresipCallID, digits: String,
                         duration: Duration = .milliseconds(160),
                         gap: Duration = .milliseconds(80)) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_send_dtmf(h, callID.rawValue, arena.cString(digits),
                                                       duration.wholeMilliseconds,
                                                       gap.wholeMilliseconds, &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func setMicrophoneMuted(_ muted: Bool, callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_microphone_muted(h, callID.rawValue, muted, &err), err)
        }
    }

    public func setAudioDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_audio_direction(h, callID.rawValue, direction.c, &err), err)
        }
    }

    public func setVideoDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_video_direction(h, callID.rawValue, direction.c, &err), err)
        }
    }

    public func setVideoEnabled(_ enabled: Bool, callID: BaresipCallID) async throws {
        try await setVideoDirection(enabled ? .sendReceive : .inactive, callID: callID)
    }

    public func setCamera(_ device: String, callID: BaresipCallID) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_camera(h, callID.rawValue, arena.cString(device), &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func requestKeyframe(callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_request_keyframe(h, callID.rawValue, &err), err)
        }
    }

    public func setVideoMaxBitrate(callID: BaresipCallID, bitsPerSecond: Int?) async throws {
        let bps = UInt32(clamping: max(0, bitsPerSecond ?? 0))
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_set_video_max_bitrate(h, callID.rawValue, bps, &err), err)
        }
    }

    public func restartICE(callID: BaresipCallID) async throws {
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_restart_ice(h, callID.rawValue, &err), err)
        }
    }

    public func transfer(callID: BaresipCallID, to targetURI: String) async throws {
        try await run { h in
            let arena = CStringArena()
            var err = bsk_error()
            try BaresipEngine.check(bsk_call_transfer(h, callID.rawValue, arena.cString(targetURI), &err), err)
            withExtendedLifetime(arena) {}
        }
    }

    public func callInfo(callID: BaresipCallID) async throws -> BaresipCallInfo {
        try await run { h in
            var info = bsk_call_info()
            let status = bsk_call_get_info(h, callID.rawValue, &info)
            guard status == BSK_OK else {
                throw BaresipError(status: BaresipStatus(status))
            }
            return BaresipCallInfo(info)
        }
    }

    public func callStatistics(callID: BaresipCallID) async throws -> BaresipCallStatistics {
        try await run { h in
            var stats = bsk_call_statistics()
            let status = bsk_call_get_statistics(h, callID.rawValue, &stats)
            guard status == BSK_OK else {
                throw BaresipError(status: BaresipStatus(status))
            }
            return BaresipCallStatistics(stats)
        }
    }

    public func activeCalls() async -> [BaresipCallID] {
        (try? await run { h -> [BaresipCallID] in
            let count = bsk_call_list(h, nil, 0)
            guard count > 0 else { return [] }
            var ids = [UInt64](repeating: 0, count: count)
            let n = bsk_call_list(h, &ids, ids.count)
            return ids.prefix(min(n, ids.count)).map { BaresipCallID(rawValue: $0) }
        }) ?? []
    }

    public var isEngineThread: Bool {
        bsk_engine_is_engine_thread(handle)
    }

    public static var abiVersion: (major: Int, minor: Int) {
        let v = bsk_abi_version()
        return (Int(v >> 16), Int(v & 0xFFFF))
    }

    public func setVideoRenderer(_ renderer: BaresipVideoRenderer?, callID: BaresipCallID,
                                 local: Bool = false) async throws {
        let key = VideoSinkKey(callID: callID, local: local)
        let box = renderer.map { VideoSinkBox(renderer: $0, callID: callID, local: local) }
        let previous = lock.withLock { () -> VideoSinkBox? in
            let old = videoSinks[key]
            videoSinks[key] = box
            return old
        }
        do {
            try await run { h in
                var err = bsk_error()
                if let box {
                    var sink = box.makeSink()
                    try BaresipEngine.check(bsk_call_set_video_sink(h, callID.rawValue, local, &sink, &err), err)
                } else {
                    try BaresipEngine.check(bsk_call_set_video_sink(h, callID.rawValue, local, nil, &err), err)
                }
            }
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

    public func startVideoPreview(device: String? = nil, renderer: BaresipVideoRenderer) async throws {
        let key = VideoSinkKey(callID: nil, local: true)
        let box = VideoSinkBox(renderer: renderer, callID: nil, local: true)
        let previous = lock.withLock { () -> VideoSinkBox? in
            let old = videoSinks[key]
            videoSinks[key] = box
            return old
        }
        do {
            try await run { h in
                let arena = CStringArena()
                var sink = box.makeSink()
                var err = bsk_error()
                try BaresipEngine.check(bsk_video_preview_start(h, arena.cString(device), &sink, &err), err)
                withExtendedLifetime(arena) {}
            }
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

    public func stopVideoPreview() async throws {
        let key = VideoSinkKey(callID: nil, local: true)
        try await run { h in
            var err = bsk_error()
            try BaresipEngine.check(bsk_video_preview_stop(h, &err), err)
        }
        let previous = lock.withLock { videoSinks.removeValue(forKey: key) }
        withExtendedLifetime(previous) {}
    }

    public func videoDevices() async -> [String] {
        (try? await run { h -> [String] in
            let needed = bsk_video_list_devices(h, nil, 0)
            guard needed > 0 else { return [] }
            var buffer = [CChar](repeating: 0, count: needed + 1)
            _ = bsk_video_list_devices(h, &buffer, buffer.count)
            return String(cString: buffer).split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        }) ?? []
    }

    public static var capabilities: [String] {
        let needed = bsk_capabilities(nil, 0)
        var buffer = [CChar](repeating: 0, count: needed + 1)
        _ = bsk_capabilities(&buffer, buffer.count)
        return String(cString: buffer).split(separator: " ").map(String.init)
    }

    public static var coreVersion: String {
        String(cString: bsk_version_string())
    }
}
