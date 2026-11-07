import BaresipKitCore

extension CoreEngine {
    func addAccount(_ account: BaresipAccountConfiguration) throws -> BaresipAccountID {
        var id: UInt64 = 0
        try Self.withArena { arena in
            var config = bsk_account_config(account, arena: arena)
            try Self.check { bsk_account_add(raw, &config, &id, &$0) }
        }
        return BaresipAccountID(rawValue: id)
    }

    func removeAccount(_ id: BaresipAccountID) throws {
        try Self.check { bsk_account_remove(raw, id.rawValue, &$0) }
    }

    func setDefaultAccount(_ id: BaresipAccountID) throws {
        try Self.check { bsk_account_set_default(raw, id.rawValue, &$0) }
    }

    func register(_ id: BaresipAccountID) throws {
        try Self.check { bsk_account_register(raw, id.rawValue, &$0) }
    }

    func unregister(_ id: BaresipAccountID) throws {
        try Self.check { bsk_account_unregister(raw, id.rawValue, &$0) }
    }

    func setCredentials(_ id: BaresipAccountID, authUser: String?, password: String) throws {
        try Self.withArena { arena in
            try Self.check {
                bsk_account_set_credentials(raw, id.rawValue, arena.cString(authUser), arena.cString(password), &$0)
            }
        }
    }

    func setContactParameters(_ id: BaresipAccountID, _ parameters: [BaresipContactParameter],
                              reregisterNow: Bool) throws {
        try Self.withArena { arena in
            try Self.check {
                bsk_account_set_contact_params(raw, id.rawValue, arena.contactParameters(parameters),
                                               parameters.count, reregisterNow, &$0)
            }
        }
    }

    func registrationState(_ id: BaresipAccountID) -> BaresipRegistrationState {
        var state = BSK_REG_NONE
        _ = bsk_account_get_registration_state(raw, id.rawValue, &state)
        return BaresipRegistrationState(state)
    }

    static func encodeContactParameters(_ parameters: [BaresipContactParameter]) throws -> String {
        try withArena { arena in
            let encoded = arena.contactParameters(parameters)
            let invalid = "invalid contact parameters"
            var needed = 0
            try checkStatus(bsk_contact_params_encode(encoded, parameters.count, nil, 0, &needed), message: invalid)
            var buffer = [CChar](repeating: 0, count: needed + 1)
            try checkStatus(bsk_contact_params_encode(encoded, parameters.count, &buffer, buffer.count, nil),
                            message: invalid)
            return string(fromNullTerminated: buffer)
        }
    }
}
