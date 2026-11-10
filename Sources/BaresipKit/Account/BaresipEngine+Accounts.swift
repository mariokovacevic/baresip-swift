extension BaresipEngine {
    /// Adds an account. The first account added becomes the default for calls and messages.
    ///
    /// Adding does not register; call ``register(accountID:)``.
    ///
    /// - Parameter account: The account settings.
    /// - Returns: The new account's identifier.
    /// - Throws: ``BaresipError`` when the settings are invalid or the engine is not running.
    public func addAccount(_ account: BaresipAccountConfiguration) async throws -> BaresipAccountID {
        try account.validate()
        return try await run { try $0.addAccount(account) }
    }

    /// Unregisters and removes an account. Its calls are hung up.
    ///
    /// When the default account is removed, the oldest remaining account becomes the default.
    ///
    /// - Parameter id: The account.
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/notFound`` for an unknown account.
    public func removeAccount(_ id: BaresipAccountID) async throws {
        try await run { try $0.removeAccount(id) }
    }

    /// Makes an account the default for calls and messages without an explicit account.
    ///
    /// - Parameter id: The account.
    /// - Throws: ``BaresipError`` with ``BaresipError/Code/notFound`` for an unknown account.
    public func setDefaultAccount(_ id: BaresipAccountID) async throws {
        try await run { try $0.setDefaultAccount(id) }
    }

    /// Starts registration. Progress arrives as ``BaresipEvent/registration(_:_:expires:error:)``.
    ///
    /// - Parameter accountID: The account.
    /// - Throws: ``BaresipError`` for an unknown account.
    public func register(accountID: BaresipAccountID) async throws {
        try await run { try $0.register(accountID) }
    }

    /// Removes the registration.
    ///
    /// - Parameter accountID: The account.
    /// - Throws: ``BaresipError`` for an unknown account.
    public func unregister(accountID: BaresipAccountID) async throws {
        try await run { try $0.unregister(accountID) }
    }

    /// Replaces an account's credentials. The next REGISTER uses them.
    ///
    /// - Parameters:
    ///   - accountID: The account.
    ///   - authUser: The authentication user name, or `nil` for the user part of the address.
    ///   - password: The password.
    /// - Throws: ``BaresipError`` for an unknown account.
    public func updateCredentials(accountID: BaresipAccountID, authUser: String?, password: String) async throws {
        try await run { try $0.setCredentials(accountID, authUser: authUser, password: password) }
    }

    /// Replaces an account's `Contact` parameters, for example when the push token changes.
    ///
    /// - Parameters:
    ///   - accountID: The account.
    ///   - parameters: The new parameters.
    ///   - reregisterNow: Whether to send a REGISTER with the new parameters right away.
    /// - Throws: ``BaresipError`` for an unknown account or invalid parameters.
    public func updateContactParameters(accountID: BaresipAccountID, parameters: [BaresipContactParameter],
                                        reregisterNow: Bool = true) async throws {
        try await run { try $0.setContactParameters(accountID, parameters, reregisterNow: reregisterNow) }
    }

    /// The accounts the engine has, each with its current registration state.
    ///
    /// Use it to show the state of accounts that were added before you started reading
    /// ``events``. The result is empty while the engine is not running.
    ///
    /// - Returns: The registration state by account.
    public func accounts() async -> [BaresipAccountID: BaresipRegistrationState] {
        await (try? run { $0.accounts() }) ?? [:]
    }

    /// The current registration state of an account, or ``BaresipRegistrationState/none`` for
    /// an unknown account.
    ///
    /// - Parameter accountID: The account.
    /// - Returns: The registration state.
    public func registrationState(accountID: BaresipAccountID) -> BaresipRegistrationState {
        core.registrationState(accountID)
    }
}
