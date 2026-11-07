import BaresipKitCore

extension bsk_engine_config {
    init(_ configuration: BaresipConfiguration, arena: CStringArena) {
        self.init()
        size = UInt32(MemoryLayout<bsk_engine_config>.size)
        user_agent = arena.cString(configuration.userAgent)
        instance_uuid = arena.cString(configuration.instanceUUID.uuidString.lowercased())
        network_interface = arena.cString(configuration.networkInterface)
        modules = arena.cStringArray(configuration.modules)
        module_count = configuration.modules.count
        extra_config = arena.cString(configuration.extraConfiguration)
        ipv6 = configuration.ipv6
        rtp_port_min = configuration.rtpPortRange.lowerBound
        rtp_port_max = configuration.rtpPortRange.upperBound
        max_calls = UInt32(clamping: configuration.maxCalls)
        log_level = configuration.logLevel.core
        log_sip_trace = configuration.logSIPTrace
        ice_relay_only = configuration.iceRelayOnly
        video_adaptive_bitrate = configuration.videoAdaptiveBitrate
        video_min_bitrate_bps = UInt32(clamping: max(0, configuration.videoMinimumBitrate))
        setAudio(configuration.audio, arena: arena)
        setVideo(configuration.video, arena: arena)
        setTLS(configuration.tls, arena: arena)
    }

    private mutating func setAudio(_ settings: BaresipAudioConfiguration, arena: CStringArena) {
        audio.source_module = arena.cString(settings.sourceModule)
        audio.source_device = arena.cString(settings.sourceDevice)
        audio.player_module = arena.cString(settings.playerModule)
        audio.player_device = arena.cString(settings.playerDevice)
        audio.sample_rate = UInt32(clamping: settings.sampleRate ?? 0)
        audio.channels = UInt32(clamping: settings.channels ?? 0)
        audio.ptime_ms = settings.packetTime.wholeMilliseconds
        audio.jitter_buffer_min_ms = UInt32(clamping: settings.jitterBufferRange.lowerBound)
        audio.jitter_buffer_max_ms = UInt32(clamping: settings.jitterBufferRange.upperBound)
        audio.jitter_buffer_adaptive = settings.adaptiveJitterBuffer
        audio.voice_processing = settings.voiceProcessing
        audio.codecs = arena.cStringArray(settings.codecs)
        audio.codec_count = settings.codecs.count
    }

    private mutating func setVideo(_ settings: BaresipVideoConfiguration, arena: CStringArena) {
        video.source_module = arena.cString(settings.sourceModule)
        video.source_device = arena.cString(settings.sourceDevice)
        video.width = UInt32(clamping: settings.width)
        video.height = UInt32(clamping: settings.height)
        video.fps = UInt32(clamping: settings.framesPerSecond)
        video.bitrate_bps = UInt32(clamping: settings.bitrate)
        video.codecs = arena.cStringArray(settings.codecs)
        video.codec_count = settings.codecs.count
        video.hardware_acceleration = settings.hardwareAcceleration
    }

    private mutating func setTLS(_ settings: BaresipTLSConfiguration, arena: CStringArena) {
        let ca = arena.bytes(settings.caCertificatesPEM)
        tls.ca_pem = ca.pointer
        tls.ca_pem_len = ca.count
        let client = arena.bytes(settings.clientCertificatePEM)
        tls.client_cert_pem = client.pointer
        tls.client_cert_pem_len = client.count
        tls.pinned_spki_sha256_base64 = arena.cStringArray(settings.pinnedSPKISHA256)
        tls.pinned_count = settings.pinnedSPKISHA256.count
        tls.cipher_list = arena.cString(settings.cipherList)
        tls.min_version = Int32(settings.minimumVersion.rawValue)
        tls.verify_server = settings.verifyServer
    }
}

extension bsk_account_config {
    init(_ account: BaresipAccountConfiguration, arena: CStringArena) {
        self.init()
        size = UInt32(MemoryLayout<bsk_account_config>.size)
        aor = arena.cString(account.aor)
        display_name = arena.cString(account.displayName)
        registrar = arena.cString(account.registrar)
        outbound_proxy = arena.cString(account.outboundProxy)
        transport = account.transport.core
        auth_user = arena.cString(account.authUser)
        auth_password = arena.cString(account.authPassword)
        register_expires = account.registerExpires.wholeSeconds
        register_retry_min_s = account.registerRetry.lowerBound.wholeSeconds
        register_retry_max_s = account.registerRetry.upperBound.wholeSeconds
        sip_outbound = account.sipOutbound
        keepalive = account.keepAlive
        media_encryption = account.mediaEncryption.core
        dtmf_mode = account.dtmfMode.core
        contact_params = arena.contactParameters(account.contactParameters)
        contact_param_count = account.contactParameters.count
        audio_codecs = arena.cStringArray(account.audioCodecs)
        audio_codec_count = account.audioCodecs.count
        video_codecs = arena.cStringArray(account.videoCodecs)
        video_codec_count = account.videoCodecs.count
        answer_early_media = account.answerEarlyMedia
        reject_transfers = !account.acceptTransfers
        setNAT(account.nat, arena: arena)
    }

    private mutating func setNAT(_ settings: BaresipNATConfiguration, arena: CStringArena) {
        nat.mode = settings.mode.core
        nat.stun_uri = arena.cString(settings.stunURI)
        nat.turn_servers = arena.turnServers(settings.turnServers)
        nat.turn_count = settings.turnServers.count
        nat.symmetric_rtp_latching = settings.symmetricRTPLatching
        nat.rtp_timeout_ms = settings.rtpTimeout.wholeMilliseconds
    }
}
