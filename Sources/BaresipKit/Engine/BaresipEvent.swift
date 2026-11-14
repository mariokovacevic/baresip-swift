/// Something that happened in the engine, delivered through ``BaresipEngine/events``.
///
/// ```swift
/// for await event in engine.events {
///     switch event {
///     case .registration(_, let state, _, _):
///         print("registration:", state)
///     case .incomingCall(let info, _):
///         try await engine.answer(callID: info.id)
///     default:
///         break
///     }
/// }
/// ```
///
/// New cases can be added in a minor release; end a `switch` over it with `default:`. See
/// [Stability](https://github.com/mariokovacevic/baresipkit/blob/main/Docs/STABILITY.md).
public enum BaresipEvent: Sendable {
    /// The engine changed state, with the error that caused a failure.
    case engine(BaresipEngineState, BaresipError?)
    /// An account's registration changed; `expires` is the granted lifetime when registered.
    case registration(BaresipAccountID, BaresipRegistrationState, expires: Duration?, error: BaresipError?)
    /// A call is ringing; `earlyVideo` is `true` when the caller offers video before answering.
    case incomingCall(BaresipCallInfo, earlyVideo: Bool)
    /// A call changed state. The error is set for ``BaresipCallState/failed``, and when the
    /// other side rejected a hold, resume or direction change and the call returned to its
    /// previous state.
    case call(BaresipCallID, BaresipCallState, BaresipError?)
    /// A call's media changed.
    case media(BaresipCallID, BaresipMediaEventInfo)
    /// A DTMF digit arrived.
    case dtmf(BaresipCallID, BaresipDTMFEvent)
    /// A transfer made progress.
    case transfer(BaresipCallID, BaresipTransferEvent)
    /// Periodic media statistics for a call.
    case statistics(BaresipCallID, BaresipCallStatistics)
    /// A call's ICE state changed.
    case ice(BaresipCallID, BaresipICEEvent)
    /// The engine handled a network change.
    case network(BaresipNetworkEvent)
    /// Audio input or output started or stopped, for a call or for the engine.
    case audio(BaresipCallID?, BaresipAudioEvent)
    /// A diagnostic condition outside a call.
    case diagnostic(BaresipDiagnosticEvent)
    /// A SIP MESSAGE arrived.
    case message(BaresipMessage)
    /// A sent SIP MESSAGE was answered or failed.
    case messageStatus(BaresipMessageStatus)
}
