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
        let id = try await run { try $0.addAccount(account) }
        lock.withLock {
            if defaultAccount == nil {
                defaultAccount = id
            }
        }
        return id
    }

    /// Unregisters and removes an account. Its calls are hung up.
    ///
    /// - Parameter id: The account.
    /// - Throws: ``BaresipError`` with ``BaresipStatus/notFound`` for an unknown account.
    public func removeAccount(_ id: BaresipAccountID) async throws {
        try await run { try $0.removeAccount(id) }
        lock.withLock {
            if defaultAccount == id {
                defaultAccount = nil
            }
        }
    }

    /// Makes an account the default for calls and messages without an explicit account.
    ///
    /// - Parameter id: The account.
    /// - Throws: ``BaresipError`` with ``BaresipStatus/notFound`` for an unknown account.
    public func setDefaultAccount(_ id: BaresipAccountID) async throws {
        try await run { try $0.setDefaultAccount(id) }
        lock.withLock {
            defaultAccount = id
        }
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

    /// The current registration state of an account, or ``BaresipRegistrationState/none`` for
    /// an unknown account.
    ///
    /// - Parameter accountID: The account.
    /// - Returns: The registration state.
    public func registrationState(accountID: BaresipAccountID) -> BaresipRegistrationState {
        core.registrationState(accountID)
    }

    func resolvedAccount(_ accountID: BaresipAccountID?) -> BaresipAccountID? {
        lock.withLock { accountID ?? defaultAccount }
    }
}
