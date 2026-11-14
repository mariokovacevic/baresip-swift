import Combine
import Foundation
import BaresipKit

/// The engine's registrations and calls as observable state for SwiftUI.
///
/// The phone applies the engine's events to its published properties while ``run()`` runs,
/// so views follow registration and call state without handling events themselves. Create it
/// once for an engine and keep it, for example as a `@StateObject` created in the view's
/// initializer:
///
/// ```swift
/// struct PhoneView: View {
///     @StateObject private var phone: BaresipPhone
///
///     init(engine: BaresipEngine) {
///         _phone = StateObject(wrappedValue: BaresipPhone(engine: engine))
///     }
///
///     var body: some View {
///         List(phone.calls) { call in
///             CallRow(call: call)
///         }
///         .task { await phone.run() }
///     }
/// }
/// ```
@MainActor
public final class BaresipPhone: ObservableObject {
    /// The engine whose events the phone applies.
    public let engine: BaresipEngine

    /// The registration state of every account of the engine.
    ///
    /// ``run()`` reads the accounts the engine already has and then follows its events.
    @Published public private(set) var registrations: [BaresipAccountID: BaresipRegistrationState] = [:]

    /// The calls that are not released yet, in the order they appeared.
    @Published public private(set) var calls: [BaresipPhoneCall] = []

    /// The call a call screen shows: the call placed or answered last, also on the system call
    /// screen, or the one made active with ``makeActive(_:)``.
    ///
    /// The first call that appears becomes active. When the active call ends, the next call
    /// becomes active, a held one first.
    @Published public private(set) var activeCall: BaresipPhoneCall?

    /// Takes call actions through a system call interface such as CallKit, for the calls it
    /// controls; see `BaresipCallController`. The calls' actions use the engine directly when it
    /// is `nil` or does not control a call.
    public var callController: BaresipCallController? {
        didSet { observeMuting(of: callController) }
    }

    /// Whether a held call is resumed when the active call ends. On by default.
    public var resumesHeldCallWhenActiveCallEnds = true

    private var releasedCalls: Set<BaresipCallID> = []
    private var observedControllers: Set<ObjectIdentifier> = []

    /// Creates a phone for an engine.
    ///
    /// - Parameters:
    ///   - engine: The engine to follow. The phone neither starts nor stops it.
    ///   - callController: Takes call actions through a system call interface such as CallKit,
    ///     or `nil` to use the engine directly.
    public init(engine: BaresipEngine, callController: BaresipCallController? = nil) {
        self.engine = engine
        self.callController = callController
        observeMuting(of: callController)
    }

    /// The first call that is ringing and not answered yet.
    public var incomingCall: BaresipPhoneCall? {
        calls.first(where: \.isRinging)
    }

    /// Applies the engine's events until the calling task is cancelled.
    ///
    /// Each run first brings ``calls`` in line with the engine: calls that started or ended while
    /// it was not running are added or removed, and the calls it already tracks get their current
    /// state and details, so a call answered in the meantime no longer reads as incoming. Run it
    /// from a SwiftUI `.task` modifier or another long-lived task; running it again after a
    /// cancellation is safe.
    public func run() async {
        let events = engine.events
        await synchronize()
        for await event in events {
            apply(event)
        }
    }

    /// The call with an identifier, if it is not released yet.
    ///
    /// - Parameter id: The call identifier.
    /// - Returns: The call, or `nil`.
    public func call(_ id: BaresipCallID) -> BaresipPhoneCall? {
        calls.first { $0.id == id }
    }

    /// Places a call and adds it to ``calls``.
    ///
    /// The call goes through ``callController`` when one is set, unless it uses another account
    /// or no audio, and becomes the ``activeCall`` unless an established call is active. When
    /// the call ends before the engine has returned it, the returned call is already in the
    /// released state and is not added to ``calls``.
    ///
    /// - Parameters:
    ///   - destination: A SIP URI, or a user or number completed with the account's domain.
    ///   - accountID: The account to call from, or `nil` for the default account.
    ///   - video: Whether to send the camera; the other side's video is received either way.
    ///   - audio: Whether to open the microphone and play the other side's audio.
    /// - Returns: The new call.
    /// - Throws: `BaresipError` when the engine cannot place the call, or the controller's error.
    public func makeCall(to destination: String, accountID: BaresipAccountID? = nil,
                         video: Bool = false, audio: Bool = true) async throws -> BaresipPhoneCall {
        let id: BaresipCallID = if let callController, accountID == nil, audio {
            try await callController.placeCall(to: destination, video: video)
        } else {
            try await engine.makeCall(accountID: accountID, destination: destination,
                                      video: video, audio: audio)
        }
        guard !releasedCalls.contains(id) else {
            let ended = BaresipPhoneCall(id: id, state: .released, engine: engine)
            ended.markOutgoing(to: destination, video: video)
            return ended
        }
        let placed = trackedCall(id, state: .outgoingInit)
        placed.markOutgoing(to: destination, video: video)
        let keepsEstablishedCall = activeCall.map { $0 !== placed && !$0.isOnHold && $0.isConnected } ?? false
        if !keepsEstablishedCall {
            activeCall = placed
        }
        placed.refresh()
        return placed
    }

    /// Makes a call the active one: the engine puts other established calls on hold and resumes
    /// this one if it was held.
    ///
    /// - Parameter call: The call to show and talk on.
    /// - Throws: `BaresipError` for a call the engine no longer has.
    public func makeActive(_ call: BaresipPhoneCall) async throws {
        if calls.count > 1 {
            try await engine.setActiveCall(call.id)
        }
        activeCall = call
        call.refresh()
    }

    func callWasAnswered(_ call: BaresipPhoneCall) async {
        guard self.call(call.id) != nil else { return }
        if calls.contains(where: { $0 !== call && $0.isConnected }) {
            try? await engine.setActiveCall(call.id)
        }
        activeCall = call
    }

    func apply(_ event: BaresipEvent) {
        switch event {
        case .registration(let account, let state, _, _):
            registrations[account] = state
        case .incomingCall(let info, _):
            guard !releasedCalls.contains(info.id) else { return }
            trackedCall(info.id, state: info.state).update(with: info)
        case .call(let id, let state, let error):
            applyState(state, error: error, to: id)
        case .media(let id, _):
            call(id)?.refresh()
        case .dtmf(let id, let dtmf):
            if !dtmf.isEnd {
                call(id)?.didReceiveDTMF(dtmf.digit)
            }
        default:
            break
        }
    }

    func synchronize() async {
        await registrations.merge(engine.accounts()) { _, latest in latest }
        let known = Set(calls.map(\.id))
        let active = await engine.activeCalls()
        for id in known.subtracting(active) {
            release(id)
        }
        for id in active where !releasedCalls.contains(id) {
            guard let info = try? await engine.callInfo(callID: id) else { continue }
            applySnapshot(of: id, state: info.state)?.update(with: info)
        }
    }

    func applySnapshot(of id: BaresipCallID, state: BaresipCallState) -> BaresipPhoneCall? {
        guard !releasedCalls.contains(id) else { return nil }
        guard state != .released else {
            release(id)
            return nil
        }
        let current = trackedCall(id, state: state)
        current.update(state: state, error: nil)
        return current
    }

    private func applyState(_ state: BaresipCallState, error: BaresipError?, to id: BaresipCallID) {
        guard state != .released else {
            release(id)
            return
        }
        guard !releasedCalls.contains(id) else { return }
        let current = trackedCall(id, state: state)
        let wasRinging = current.isRinging
        current.update(state: state, error: error)
        let answeredElsewhere = wasRinging && current.isConnected
        if answeredElsewhere {
            activeCall = current
        }
        current.refresh()
    }

    private func release(_ id: BaresipCallID) {
        releasedCalls.insert(id)
        call(id)?.update(state: .released, error: nil)
        calls.removeAll { $0.id == id }
        guard activeCall?.id == id else { return }
        let next = calls.first(where: \.isOnHold) ?? calls.first
        activeCall = next
        if let next, next.isOnHold, resumesHeldCallWhenActiveCallEnds {
            Task { try? await next.setOnHold(false) }
        }
    }

    private func trackedCall(_ id: BaresipCallID, state: BaresipCallState) -> BaresipPhoneCall {
        if let existing = call(id) {
            return existing
        }
        let newCall = BaresipPhoneCall(id: id, state: state, engine: engine)
        newCall.phone = self
        calls.append(newCall)
        if activeCall == nil {
            activeCall = newCall
        }
        return newCall
    }

    private func observeMuting(of controller: BaresipCallController?) {
        guard let controller, observedControllers.insert(ObjectIdentifier(controller)).inserted else { return }
        controller.addMuteObserver { [weak self] id, muted in
            Task { @MainActor [weak self] in
                self?.call(id)?.applyMuted(muted)
            }
        }
    }
}
