import BaresipKitCore

extension RawRepresentable where RawValue == Int {
    init(coreValue: UInt32, fallback: Self) {
        self = Self(rawValue: Int(coreValue)) ?? fallback
    }

    var coreValue: UInt32 {
        UInt32(rawValue)
    }
}

extension BaresipStatus {
    init(_ value: bsk_status) {
        self.init(coreValue: value.rawValue, fallback: .internalError)
    }
}

extension BaresipLogLevel {
    init(_ value: bsk_log_level) {
        self.init(coreValue: value.rawValue, fallback: .info)
    }

    var core: bsk_log_level {
        bsk_log_level(coreValue)
    }
}

extension BaresipLogDomain {
    init(_ value: bsk_log_domain) {
        self.init(coreValue: value.rawValue, fallback: .core)
    }
}

extension BaresipEngineState {
    init(_ value: bsk_engine_state) {
        self.init(coreValue: value.rawValue, fallback: .failed)
    }
}

extension BaresipRegistrationState {
    init(_ value: bsk_registration_state) {
        self.init(coreValue: value.rawValue, fallback: .none)
    }
}

extension BaresipCallState {
    init(_ value: bsk_call_state) {
        self.init(coreValue: value.rawValue, fallback: .failed)
    }
}

extension BaresipMediaDirection {
    init(_ value: bsk_media_direction) {
        self.init(coreValue: value.rawValue, fallback: .inactive)
    }

    var core: bsk_media_direction {
        bsk_media_direction(coreValue)
    }
}

extension BaresipMediaEvent {
    init(_ value: bsk_media_event) {
        self.init(coreValue: value.rawValue, fallback: .unknown)
    }
}

extension BaresipICEState {
    init(_ value: bsk_ice_state) {
        self.init(coreValue: value.rawValue, fallback: .none)
    }
}

extension BaresipCandidateType {
    init(_ value: bsk_candidate_type) {
        self.init(coreValue: value.rawValue, fallback: .host)
    }
}

extension BaresipPixelFormat {
    init(_ value: bsk_pixel_format) {
        self.init(coreValue: value.rawValue, fallback: .nv12)
    }
}

extension BaresipTransport {
    var core: bsk_transport {
        bsk_transport(coreValue)
    }
}

extension BaresipMediaEncryption {
    var core: bsk_media_encryption {
        bsk_media_encryption(coreValue)
    }
}

extension BaresipNATTraversal {
    var core: bsk_nat_traversal {
        bsk_nat_traversal(coreValue)
    }
}

extension BaresipDTMFMode {
    var core: bsk_dtmf_mode {
        bsk_dtmf_mode(coreValue)
    }
}
