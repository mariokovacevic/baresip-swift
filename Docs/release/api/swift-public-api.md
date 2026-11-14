# Swift public API surface (generated)

Generated from source with: grep -rnE '^\s*(@[A-Za-z]+\s+)*(public|open)\b' Sources --include=*.swift (declarations only; extensions listed with their members).
Not a compiler-generated digest: no Swift toolchain was available. Regenerate with swift-api-digester or swift package diagnose-api-breaking-changes on macOS.

## BaresipKit (337 declarations)

```
Messaging/BaresipMessage.swift:4:public struct BaresipMessage: Sendable, Equatable
Messaging/BaresipMessage.swift:6: public let accountID: BaresipAccountID?
Messaging/BaresipMessage.swift:8: public let from: String
Messaging/BaresipMessage.swift:10: public let contentType: String
Messaging/BaresipMessage.swift:12: public let body: Data
Messaging/BaresipMessage.swift:15: public var text: String?
Messaging/BaresipEngine+Messages.swift:14: public func sendMessage(to peerURI: String, text: String,
Messaging/BaresipMessageStatus.swift:2:public struct BaresipMessageStatus: Sendable, Equatable
Messaging/BaresipMessageStatus.swift:4: public let id: BaresipMessageID
Messaging/BaresipMessageStatus.swift:6: public let delivered: Bool
Messaging/BaresipMessageStatus.swift:8: public let sipStatus: Int?
Messaging/BaresipMessageStatus.swift:10: public let error: BaresipError?
Messaging/BaresipMessageID.swift:5:public struct BaresipMessageID: Hashable, Sendable, Codable, CustomStringConvertible
Messaging/BaresipMessageID.swift:7: public let rawValue: UInt64
Messaging/BaresipMessageID.swift:12: public init(rawValue: UInt64)
Messaging/BaresipMessageID.swift:17: public var description: String
Network/BaresipNATConfiguration.swift:2:public struct BaresipNATConfiguration: Sendable, Equatable
Network/BaresipNATConfiguration.swift:4: public var mode: BaresipNATTraversal
Network/BaresipNATConfiguration.swift:6: public var stunURI: String?
Network/BaresipNATConfiguration.swift:8: public var turnServers: [BaresipTURNServer]
Network/BaresipNATConfiguration.swift:10: public var rtpTimeout: Duration
Network/BaresipNATConfiguration.swift:16: public var rtcpMultiplexing: Bool
Network/BaresipNATConfiguration.swift:24: public var pinhole: Bool
Network/BaresipNATConfiguration.swift:35: public init(mode: BaresipNATTraversal = .none, stunURI: String? = nil,
Network/BaresipCertificates.swift:5:public enum BaresipCertificateError: Error, Equatable, Sendable
Network/BaresipCertificates.swift:20: public var errorDescription: String?
Network/BaresipCertificates.swift:40:public enum BaresipCertificates
Network/BaresipCertificates.swift:98: public static func caBundle(from data: Data) throws -> Data
Network/BaresipCertificates.swift:122: public static func clientIdentity(from data: Data) throws -> Data
Network/BaresipCertificates.swift:145: public static func split(_ identity: Data?) -> (certificates: String, key: String)
Network/BaresipCertificates.swift:156: public static func summaries(_ pem: Data?) -> [String]
Network/BaresipCandidateType.swift:2:public enum BaresipCandidateType: Int, Sendable, Codable
Network/BaresipNetworkMonitor.swift:5:public struct BaresipNetworkPath: Sendable, Equatable
Network/BaresipNetworkMonitor.swift:7: public let interfaceSummary: String
Network/BaresipNetworkMonitor.swift:9: public let isSatisfied: Bool
Network/BaresipNetworkMonitor.swift:23:public final class BaresipNetworkMonitor: @unchecked Sendable
Network/BaresipNetworkMonitor.swift:42: public init(engine: BaresipEngine, reregister: Bool = true, updateCalls: Bool = true)
Network/BaresipNetworkMonitor.swift:55: public func setChangeHandler(_ handler: (@Sendable (BaresipNetworkPath) -> Void)?)
Network/BaresipNetworkMonitor.swift:60: public func start()
Network/BaresipNetworkMonitor.swift:73: public func stop()
Network/BaresipICEEvent.swift:2:public struct BaresipICEEvent: Sendable, Equatable
Network/BaresipICEEvent.swift:4: public let state: BaresipICEState
Network/BaresipICEEvent.swift:6: public let localCandidate: BaresipCandidateType
Network/BaresipICEEvent.swift:8: public let remoteCandidate: BaresipCandidateType
Network/BaresipICEEvent.swift:10: public let localAddress: String
Network/BaresipICEEvent.swift:12: public let remoteAddress: String
Network/BaresipNetworkEvent.swift:2:public struct BaresipNetworkEvent: Sendable, Equatable
Network/BaresipNetworkEvent.swift:4: public let transportsReset: Bool
Network/BaresipNetworkEvent.swift:6: public let localAddress: String
Network/BaresipNetworkEvent.swift:13: public init(transportsReset: Bool, localAddress: String)
Network/BaresipEngine+Network.swift:6: public func restartICE(callID: BaresipCallID) async throws
Network/BaresipTURNServer.swift:5:public struct BaresipTURNServer: Hashable, Sendable, Codable
Network/BaresipTURNServer.swift:7: public let uri: String
Network/BaresipTURNServer.swift:9: public let username: String?
Network/BaresipTURNServer.swift:11: public let password: String?
Network/BaresipTURNServer.swift:19: public init(uri: String, username: String? = nil, password: String? = nil)
Network/BaresipICEState.swift:2:public enum BaresipICEState: Int, Sendable, Codable
Network/BaresipNATTraversal.swift:2:public enum BaresipNATTraversal: Int, Sendable, Codable
Network/BaresipTLSConfiguration.swift:8:public struct BaresipTLSConfiguration: Sendable, Equatable
Network/BaresipTLSConfiguration.swift:10: public var caCertificatesPEM: Data?
Network/BaresipTLSConfiguration.swift:12: public var clientCertificatePEM: Data?
Network/BaresipTLSConfiguration.swift:14: public var pinnedSPKISHA256: [String]
Network/BaresipTLSConfiguration.swift:16: public var cipherList: String?
Network/BaresipTLSConfiguration.swift:18: public var minimumVersion: TLSVersion
Network/BaresipTLSConfiguration.swift:23: public private(set) var verifyServer: Bool
Network/BaresipTLSConfiguration.swift:26: public enum TLSVersion: Int, Sendable, Codable
Network/BaresipTLSConfiguration.swift:41: public init(caCertificatesPEM: Data? = nil, clientCertificatePEM: Data? = nil,
Network/BaresipTLSConfiguration.swift:59: public static func insecureSkippingServerVerification() -> BaresipTLSConfiguration
Call/BaresipDTMFEvent.swift:2:public struct BaresipDTMFEvent: Sendable, Equatable
Call/BaresipDTMFEvent.swift:4: public let digit: Character
Call/BaresipDTMFEvent.swift:6: public let isEnd: Bool
Call/BaresipDTMFEvent.swift:8: public let viaSIPInfo: Bool
Call/BaresipCallInfo.swift:3:public struct BaresipCallInfo: Sendable, Equatable
Call/BaresipCallInfo.swift:5: public let id: BaresipCallID
Call/BaresipCallInfo.swift:7: public let account: BaresipAccountID
Call/BaresipCallInfo.swift:9: public let state: BaresipCallState
Call/BaresipCallInfo.swift:11: public let isOutgoing: Bool
Call/BaresipCallInfo.swift:13: public let hasVideo: Bool
Call/BaresipCallInfo.swift:15: public let audioDirection: BaresipMediaDirection
Call/BaresipCallInfo.swift:19: public let videoDirection: BaresipMediaDirection
Call/BaresipCallInfo.swift:21: public let sipCallID: String
Call/BaresipCallInfo.swift:23: public let remoteURI: String
Call/BaresipCallInfo.swift:25: public let remoteDisplayName: String
Call/BaresipCallInfo.swift:27: public let audioCodec: String
Call/BaresipCallInfo.swift:29: public let videoCodec: String
Call/BaresipCallInfo.swift:31: public let setupTime: Duration
Call/BaresipCallInfo.swift:33: public let duration: Duration
Call/BaresipCallInfo.swift:35: public let isMicrophoneMuted: Bool
Call/BaresipCallInfo.swift:40: public let replacesCallID: BaresipCallID?
Call/BaresipEngine+Calls.swift:25: public func makeCall(accountID: BaresipAccountID? = nil, destination: String,
Call/BaresipEngine+Calls.swift:43: public func answer(callID: BaresipCallID, video: Bool = false, audio: Bool = true) async throws
Call/BaresipEngine+Calls.swift:59: public func sendProgress(callID: BaresipCallID, earlyVideo: Bool = false,
Call/BaresipEngine+Calls.swift:72: public func reject(callID: BaresipCallID, statusCode: Int = 486, reason: String? = nil) async throws
Call/BaresipEngine+Calls.swift:81: public func hangup(callID: BaresipCallID) async throws
Call/BaresipEngine+Calls.swift:92: public func hold(callID: BaresipCallID) async throws
Call/BaresipEngine+Calls.swift:100: public func resume(callID: BaresipCallID) async throws
Call/BaresipEngine+Calls.swift:109: public func setActiveCall(_ callID: BaresipCallID) async throws
Call/BaresipEngine+Calls.swift:121: public func sendDTMF(callID: BaresipCallID, digits: String,
Call/BaresipEngine+Calls.swift:133: public func blindTransfer(callID: BaresipCallID, to targetURI: String) async throws
Call/BaresipEngine+Calls.swift:148: public func attendedTransfer(callID: BaresipCallID,
Call/BaresipEngine+Calls.swift:158: public func callInfo(callID: BaresipCallID) async throws -> BaresipCallInfo
Call/BaresipEngine+Calls.swift:171: public func incomingHeader(_ name: String, callID: BaresipCallID) async throws -> String?
Call/BaresipEngine+Calls.swift:178: public func activeCalls() async -> [BaresipCallID]
Call/BaresipTransferEvent.swift:2:public struct BaresipTransferEvent: Sendable, Equatable
Call/BaresipTransferEvent.swift:4: public let failed: Bool
Call/BaresipTransferEvent.swift:6: public let sipStatus: Int?
Call/BaresipTransferEvent.swift:8: public let targetURI: String
Call/BaresipRedialRequest.swift:24: public struct BaresipRedialRequest: Sendable, Equatable
Call/BaresipRedialRequest.swift:26: public static let activityType = "INStartCallIntent"
Call/BaresipRedialRequest.swift:29: public let destination: String
Call/BaresipRedialRequest.swift:31: public let video: Bool
Call/BaresipRedialRequest.swift:38: public init(destination: String, video: Bool)
Call/BaresipRedialRequest.swift:47: public init?(activity: NSUserActivity)
Call/BaresipCallState.swift:5:public enum BaresipCallState: Int, Sendable, Codable
Call/BaresipCallState.swift:36: public var isTerminal: Bool
Call/BaresipHandleStyle.swift:3:public enum BaresipHandleStyle: Sendable, Equatable
Call/BaresipCallID.swift:5:public struct BaresipCallID: Hashable, Sendable, Codable, CustomStringConvertible
Call/BaresipCallID.swift:7: public let rawValue: UInt64
Call/BaresipCallID.swift:12: public init(rawValue: UInt64)
Call/BaresipCallID.swift:17: public var description: String
Call/BaresipCallController.swift:11:public protocol BaresipCallController: AnyObject, Sendable
Call/BaresipDTMFMode.swift:2:public enum BaresipDTMFMode: Int, Sendable, Codable
Diagnostics/BaresipEngine+Statistics.swift:7: public func callStatistics(callID: BaresipCallID) async throws -> BaresipCallStatistics
Diagnostics/BaresipCallStatistics.swift:3:public struct BaresipCallStatistics: Sendable, Equatable
Diagnostics/BaresipCallStatistics.swift:5: public let id: BaresipCallID
Diagnostics/BaresipCallStatistics.swift:7: public let audio: BaresipStreamStatistics
Diagnostics/BaresipCallStatistics.swift:9: public let video: BaresipStreamStatistics
Diagnostics/BaresipCallStatistics.swift:11: public let iceState: BaresipICEState
Diagnostics/BaresipCallStatistics.swift:13: public let localCandidate: BaresipCandidateType
Diagnostics/BaresipCallStatistics.swift:15: public let remoteCandidate: BaresipCandidateType
Diagnostics/BaresipCallStatistics.swift:17: public let localAddress: String
Diagnostics/BaresipCallStatistics.swift:19: public let remoteAddress: String
Diagnostics/BaresipCallStatistics.swift:21: public let mosEstimate: Float
Diagnostics/BaresipCallStatistics.swift:23: public let videoTargetBitrate: Int
Diagnostics/BaresipError.swift:13:public struct BaresipError: Error, Sendable, Equatable, CustomStringConvertible
Diagnostics/BaresipError.swift:15: public let code: Code
Diagnostics/BaresipError.swift:17: public let systemErrno: Int32
Diagnostics/BaresipError.swift:19: public let sipStatus: Int?
Diagnostics/BaresipError.swift:21: public let sipReason: String
Diagnostics/BaresipError.swift:23: public let message: String
Diagnostics/BaresipError.swift:33: public let endReason: BaresipCallEndReason?
Diagnostics/BaresipError.swift:44: public init(code: Code, systemErrno: Int32 = 0, sipStatus: Int? = nil,
Diagnostics/BaresipError.swift:55: public var isFailure: Bool
Diagnostics/BaresipError.swift:60: public var description: String
Diagnostics/BaresipError.swift:78: public enum Code: Int, Sendable, Codable
Diagnostics/BaresipError.swift:113:public enum BaresipCallEndReason: Sendable, Equatable
Diagnostics/BaresipOSLog.swift:4:public enum BaresipOSLog
Diagnostics/BaresipOSLog.swift:15: public static func handler(subsystem: String = "BaresipKit") -> BaresipLogHandler
Diagnostics/BaresipStreamStatistics.swift:2:public struct BaresipStreamStatistics: Sendable, Equatable
Diagnostics/BaresipStreamStatistics.swift:4: public let transmittedPackets: UInt32
Diagnostics/BaresipStreamStatistics.swift:6: public let receivedPackets: UInt32
Diagnostics/BaresipStreamStatistics.swift:8: public let transmittedBytes: UInt64
Diagnostics/BaresipStreamStatistics.swift:10: public let receivedBytes: UInt64
Diagnostics/BaresipStreamStatistics.swift:12: public let receivedLost: Int32
Diagnostics/BaresipStreamStatistics.swift:14: public let receivedFractionLostPermille: UInt32
Diagnostics/BaresipStreamStatistics.swift:16: public let receivedJitter: Duration
Diagnostics/BaresipStreamStatistics.swift:18: public let roundTripTime: Duration
Diagnostics/BaresipStreamStatistics.swift:20: public let transmitBitrate: UInt32
Diagnostics/BaresipStreamStatistics.swift:22: public let receiveBitrate: UInt32
Diagnostics/BaresipStreamStatistics.swift:24: public let jitterBufferDelay: Duration
Diagnostics/BaresipStreamStatistics.swift:26: public let isSecure: Bool
Diagnostics/BaresipLogDomain.swift:2:public enum BaresipLogDomain: Int, Sendable, Codable
Diagnostics/BaresipDiagnosticEvent.swift:2:public struct BaresipDiagnosticEvent: Sendable, Equatable
Diagnostics/BaresipDiagnosticEvent.swift:4: public let level: BaresipLogLevel
Diagnostics/BaresipDiagnosticEvent.swift:6: public let message: String
Diagnostics/BaresipFileLog.swift:9:public final class BaresipFileLog: @unchecked Sendable
Diagnostics/BaresipFileLog.swift:42: public init(directory: URL? = nil, maxFileSize: UInt64 = 50 * 1024 * 1024, daysToKeep: Int = 7)
Diagnostics/BaresipFileLog.swift:71: public func write(_ message: String, tag: String = "app")
Diagnostics/BaresipFileLog.swift:84: public func handler(forwardingTo next: BaresipLogHandler? = nil) -> BaresipLogHandler
Diagnostics/BaresipFileLog.swift:93: public func files() -> [URL]
Diagnostics/BaresipLogEntry.swift:5:public struct BaresipLogEntry: Sendable
Diagnostics/BaresipLogEntry.swift:7: public let level: BaresipLogLevel
Diagnostics/BaresipLogEntry.swift:9: public let domain: BaresipLogDomain
Diagnostics/BaresipLogEntry.swift:11: public let message: String
Diagnostics/BaresipLogEntry.swift:17:public typealias BaresipLogHandler = @Sendable (BaresipLogEntry) -> Void
Diagnostics/BaresipLogLevel.swift:2:public enum BaresipLogLevel: Int, Sendable, Comparable, Codable
Diagnostics/BaresipLogLevel.swift:18: public static func < (lhs: BaresipLogLevel, rhs: BaresipLogLevel) -> Bool
Engine/BaresipAppLifecycle.swift:28: public final class BaresipAppLifecycle
Engine/BaresipAppLifecycle.swift:30: public enum BackgroundBehavior: Sendable, Equatable
Engine/BaresipAppLifecycle.swift:42: public enum Change: Sendable, Equatable
Engine/BaresipAppLifecycle.swift:54: public let engine: BaresipEngine
Engine/BaresipAppLifecycle.swift:58: public var backgroundBehavior: BackgroundBehavior = .suspend
Engine/BaresipAppLifecycle.swift:62: public var disconnectsOnTermination = true
Engine/BaresipAppLifecycle.swift:65: public var unregisterTimeout: Duration = .seconds(2)
Engine/BaresipAppLifecycle.swift:69: public private(set) var isAway = false
Engine/BaresipAppLifecycle.swift:87: public init(engine: BaresipEngine)
Engine/BaresipAppLifecycle.swift:94: public func setChangeHandler(_ handler: (@MainActor (Change) -> Void)?)
Engine/BaresipAppLifecycle.swift:99: public func start()
Engine/BaresipAppLifecycle.swift:128: public func stop()
Engine/BaresipEngine+Lifecycle.swift:8: public func start() async throws
Engine/BaresipEngine+Lifecycle.swift:17: public func stop(timeout: Duration = .seconds(3)) async
Engine/BaresipEngine+Lifecycle.swift:30: public func prepareForPushWakeUp() async throws
Engine/BaresipEngine+Lifecycle.swift:37: public func suspend() async throws
Engine/BaresipEngine+Lifecycle.swift:44: public func resumeFromBackground() async throws
Engine/BaresipEngine+Lifecycle.swift:56: public func networkDidChange(reregister: Bool = true, updateCalls: Bool = true) async
Engine/BaresipEngine+Lifecycle.swift:61: public func audioSessionDidActivate() async
Engine/BaresipEngine+Lifecycle.swift:66: public func audioSessionDidDeactivate() async
Engine/BaresipEngine+Lifecycle.swift:71: public func audioRouteDidChange() async
Engine/BaresipEngine+Lifecycle.swift:78: public func audioInterruption(began: Bool) async
Engine/BaresipEvent.swift:15:public enum BaresipEvent: Sendable
Engine/BaresipEngineState.swift:2:public enum BaresipEngineState: Int, Sendable, Codable
Engine/BaresipEngine.swift:18:public final class BaresipEngine: @unchecked Sendable
Engine/BaresipEngine.swift:23: public let configuration: BaresipConfiguration
Engine/BaresipEngine.swift:36: public init(configuration: BaresipConfiguration) throws
Engine/BaresipEngine.swift:58: public var events: AsyncStream<BaresipEvent>
Engine/BaresipEngine.swift:76: public func setLogHandler(_ handler: BaresipLogHandler?)
Engine/BaresipEngine.swift:83: public var state: BaresipEngineState
Engine/BaresipEngine.swift:88: public var isEngineThread: Bool
Engine/BaresipEngine.swift:93: public static var abiVersion: (major: Int, minor: Int)
Engine/BaresipEngine.swift:98: public static var capabilities: [String]
Engine/BaresipEngine.swift:103: public static var coreVersion: String
Engine/BaresipEngine.swift:113: public static func encodeContactParameters(_ parameters: [BaresipContactParameter]) throws -> String
Engine/BaresipConfiguration.swift:6:public struct BaresipConfiguration: Sendable, Equatable
Engine/BaresipConfiguration.swift:8: public var userAgent: String
Engine/BaresipConfiguration.swift:10: public var instanceUUID: UUID
Engine/BaresipConfiguration.swift:12: public var networkInterface: String?
Engine/BaresipConfiguration.swift:14: public var modules: [String]
Engine/BaresipConfiguration.swift:16: public var extraConfiguration: String?
Engine/BaresipConfiguration.swift:18: public var ipv6: Bool
Engine/BaresipConfiguration.swift:20: public var rtpPortRange: ClosedRange<UInt16>
Engine/BaresipConfiguration.swift:22: public var maxCalls: Int
Engine/BaresipConfiguration.swift:24: public var audio: BaresipAudioConfiguration
Engine/BaresipConfiguration.swift:26: public var video: BaresipVideoConfiguration
Engine/BaresipConfiguration.swift:28: public var tls: BaresipTLSConfiguration
Engine/BaresipConfiguration.swift:30: public var logLevel: BaresipLogLevel
Engine/BaresipConfiguration.swift:32: public var logSIPTrace: Bool
Engine/BaresipConfiguration.swift:34: public var iceRelayOnly: Bool
Engine/BaresipConfiguration.swift:36: public var videoAdaptiveBitrate: Bool
Engine/BaresipConfiguration.swift:38: public var videoMinimumBitrate: Int
Engine/BaresipConfiguration.swift:46: public var sessionTimer: Duration?
Engine/BaresipConfiguration.swift:48: public var minimumSessionTimer: Duration
Engine/BaresipConfiguration.swift:52: public static let defaultModules: [String] = [
Engine/BaresipConfiguration.swift:79: public init(userAgent: String = "BaresipKit", instanceUUID: UUID = UUID(),
Account/BaresipContactParameter.swift:13:public struct BaresipContactParameter: Hashable, Sendable, Codable
Account/BaresipContactParameter.swift:15: public let name: String
Account/BaresipContactParameter.swift:17: public let value: String?
Account/BaresipContactParameter.swift:24: public init(name: String, value: String?)
Account/BaresipContactParameter.swift:34: public init(_ name: String, _ value: String)
Account/BaresipAccountConfiguration.swift:11:public struct BaresipAccountConfiguration: Sendable, Equatable
Account/BaresipAccountConfiguration.swift:13: public var aor: String
Account/BaresipAccountConfiguration.swift:15: public var displayName: String?
Account/BaresipAccountConfiguration.swift:17: public var registrar: String?
Account/BaresipAccountConfiguration.swift:19: public var outboundProxy: String?
Account/BaresipAccountConfiguration.swift:21: public var transport: BaresipTransport
Account/BaresipAccountConfiguration.swift:23: public var authUser: String?
Account/BaresipAccountConfiguration.swift:25: public var authPassword: String?
Account/BaresipAccountConfiguration.swift:27: public var registerExpires: Duration
Account/BaresipAccountConfiguration.swift:29: public var sipOutbound: Bool
Account/BaresipAccountConfiguration.swift:31: public var mediaEncryption: BaresipMediaEncryption
Account/BaresipAccountConfiguration.swift:33: public var nat: BaresipNATConfiguration
Account/BaresipAccountConfiguration.swift:35: public var dtmfMode: BaresipDTMFMode
Account/BaresipAccountConfiguration.swift:37: public var contactParameters: [BaresipContactParameter]
Account/BaresipAccountConfiguration.swift:39: public var audioCodecs: [String]
Account/BaresipAccountConfiguration.swift:41: public var videoCodecs: [String]
Account/BaresipAccountConfiguration.swift:43: public var answerEarlyMedia: Bool
Account/BaresipAccountConfiguration.swift:45: public var acceptTransfers: Bool
Account/BaresipAccountConfiguration.swift:52: public var pictureUpdateOverSIPInfo: Bool
Account/BaresipAccountConfiguration.swift:55: public var incomingHeaders: [String]
Account/BaresipAccountConfiguration.swift:79: public init(aor: String, displayName: String? = nil, registrar: String? = nil,
Account/BaresipAccountConfiguration.swift:120: public func validate() throws
Account/BaresipAccountID.swift:5:public struct BaresipAccountID: Hashable, Sendable, Codable, CustomStringConvertible
Account/BaresipAccountID.swift:7: public let rawValue: UInt64
Account/BaresipAccountID.swift:12: public init(rawValue: UInt64)
Account/BaresipAccountID.swift:17: public var description: String
Account/BaresipTransport.swift:2:public enum BaresipTransport: Int, Sendable, Codable
Account/BaresipRegistrationState.swift:2:public enum BaresipRegistrationState: Int, Sendable, Codable
Account/BaresipEngine+Accounts.swift:9: public func addAccount(_ account: BaresipAccountConfiguration) async throws -> BaresipAccountID
Account/BaresipEngine+Accounts.swift:20: public func removeAccount(_ id: BaresipAccountID) async throws
Account/BaresipEngine+Accounts.swift:28: public func setDefaultAccount(_ id: BaresipAccountID) async throws
Account/BaresipEngine+Accounts.swift:36: public func register(accountID: BaresipAccountID) async throws
Account/BaresipEngine+Accounts.swift:44: public func unregister(accountID: BaresipAccountID) async throws
Account/BaresipEngine+Accounts.swift:55: public func updateCredentials(accountID: BaresipAccountID, authUser: String?, password: String) async throws
Account/BaresipEngine+Accounts.swift:66: public func updateContactParameters(accountID: BaresipAccountID, parameters: [BaresipContactParameter],
Account/BaresipEngine+Accounts.swift:77: public func accounts() async -> [BaresipAccountID: BaresipRegistrationState]
Account/BaresipEngine+Accounts.swift:86: public func registrationState(accountID: BaresipAccountID) -> BaresipRegistrationState
Media/BaresipEngine+Media.swift:10: public func setMicrophoneMuted(_ muted: Bool, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:20: public func setAudioDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:30: public func setVideoDirection(_ direction: BaresipMediaDirection, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:44: public func setVideoEnabled(_ enabled: Bool, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:54: public func setCamera(_ device: String, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:64: public func setCamera(_ position: BaresipCameraPosition, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:72: public func requestKeyframe(callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:82: public func setVideoMaxBitrate(_ bitsPerSecond: Int?, callID: BaresipCallID) async throws
Media/BaresipEngine+Media.swift:100: public func startRecording(callID: BaresipCallID, to fileURL: URL) async throws
Media/BaresipEngine+Media.swift:111: public func stopRecording(callID: BaresipCallID) async throws
Media/BaresipMediaDirection.swift:2:public enum BaresipMediaDirection: Int, Sendable, Codable
Media/BaresipAudioEvent.swift:2:public struct BaresipAudioEvent: Sendable, Equatable
Media/BaresipAudioEvent.swift:4: public let inputRunning: Bool
Media/BaresipAudioEvent.swift:6: public let outputRunning: Bool
Media/BaresipAudioEvent.swift:8: public let error: BaresipError?
Media/BaresipVideoConfiguration.swift:2:public struct BaresipVideoConfiguration: Sendable, Equatable
Media/BaresipVideoConfiguration.swift:4: public var sourceModule: String
Media/BaresipVideoConfiguration.swift:6: public var sourceDevice: String?
Media/BaresipVideoConfiguration.swift:8: public var width: Int
Media/BaresipVideoConfiguration.swift:10: public var height: Int
Media/BaresipVideoConfiguration.swift:12: public var framesPerSecond: Int
Media/BaresipVideoConfiguration.swift:14: public var bitrate: Int
Media/BaresipVideoConfiguration.swift:16: public var codecs: [String]
Media/BaresipVideoConfiguration.swift:28: public init(sourceModule: String = "bskcapture", sourceDevice: String? = nil,
Media/BaresipMediaEncryption.swift:2:public enum BaresipMediaEncryption: Int, Sendable, Codable
Media/BaresipEngine+Video.swift:12: public func setVideoRenderer(_ renderer: BaresipVideoRenderer?, callID: BaresipCallID,
Media/BaresipEngine+Video.swift:25: public func startVideoPreview(device: String? = nil, renderer: BaresipVideoRenderer) async throws
Media/BaresipEngine+Video.swift:34: public func stopVideoPreview() async throws
Media/BaresipEngine+Video.swift:43: public func videoDevices() async -> [String]
Media/BaresipCameraPosition.swift:2:public enum BaresipCameraPosition: String, Sendable, Codable, CaseIterable
Media/BaresipCameraPosition.swift:9: public var deviceName: String
Media/BaresipCameraPosition.swift:14: public var toggled: BaresipCameraPosition
Media/BaresipCameraPosition.swift:19: public var isMirroredInPreview: Bool
Media/BaresipMediaEventInfo.swift:2:public struct BaresipMediaEventInfo: Sendable, Equatable
Media/BaresipMediaEventInfo.swift:4: public let event: BaresipMediaEvent
Media/BaresipMediaEventInfo.swift:6: public let audioDirection: BaresipMediaDirection
Media/BaresipMediaEventInfo.swift:8: public let videoDirection: BaresipMediaDirection
Media/BaresipMediaEventInfo.swift:10: public let detail: String
Media/BaresipPixelFormat.swift:4:public enum BaresipPixelFormat: Int, Sendable, Codable
Media/BaresipVideoRenderer.swift:6:public protocol BaresipVideoRenderer: AnyObject, Sendable
Media/BaresipAudioConfiguration.swift:4:public struct BaresipAudioConfiguration: Sendable, Equatable
Media/BaresipAudioConfiguration.swift:6: public var sourceModule: String
Media/BaresipAudioConfiguration.swift:8: public var sourceDevice: String?
Media/BaresipAudioConfiguration.swift:10: public var playerModule: String
Media/BaresipAudioConfiguration.swift:12: public var playerDevice: String?
Media/BaresipAudioConfiguration.swift:14: public var sampleRate: Int?
Media/BaresipAudioConfiguration.swift:16: public var channels: Int?
Media/BaresipAudioConfiguration.swift:18: public var packetTime: Duration
Media/BaresipAudioConfiguration.swift:20: public var jitterBufferRange: ClosedRange<Int>
Media/BaresipAudioConfiguration.swift:22: public var adaptiveJitterBuffer: Bool
Media/BaresipAudioConfiguration.swift:24: public var codecs: [String]
Media/BaresipAudioConfiguration.swift:32: public var holdMusicFile: URL?
Media/BaresipAudioConfiguration.swift:36: public static let defaultCodecs = ["opus/48000/2", "G722/16000/1", "PCMU/8000/1", "PCMA/8000/1"]
Media/BaresipAudioConfiguration.swift:52: public init(sourceModule: String = "audiounit", sourceDevice: String? = nil,
Media/BaresipMediaEvent.swift:2:public enum BaresipMediaEvent: Int, Sendable, Codable
Media/BaresipVideoFrame.swift:9:public struct BaresipVideoFrame: @unchecked Sendable
Media/BaresipVideoFrame.swift:14: public let pixelBuffer: CVPixelBuffer
Media/BaresipVideoFrame.swift:16: public let timestamp: Duration
Media/BaresipVideoFrame.swift:18: public let rotationDegrees: Int
Media/BaresipVideoFrame.swift:20: public let width: Int
Media/BaresipVideoFrame.swift:22: public let height: Int
Media/BaresipVideoFrame.swift:30: public init(pixelBuffer: CVPixelBuffer, timestamp: Duration, rotationDegrees: Int)
```

## BaresipKitAudio (20 declarations)

```
BaresipAudioOutput.swift:4:public struct BaresipAudioOutput: Identifiable, Hashable, Sendable
BaresipAudioOutput.swift:6: public let id: String
BaresipAudioOutput.swift:8: public let name: String
BaresipAudioOutput.swift:10: public let route: BaresipAudioRoute
BaresipAudioOutput.swift:13: public static let earpiece = BaresipAudioOutput(id: "bsk.earpiece", name: "iPhone", route: .earpiece)
BaresipAudioOutput.swift:15: public static let speaker = BaresipAudioOutput(id: "bsk.speaker", name: "Speaker", route: .speaker)
BaresipAudioSessionController.swift:24: public final class BaresipAudioSessionController
BaresipAudioSessionController.swift:39: public init(engine: BaresipEngine, session: AVAudioSession = .sharedInstance(),
BaresipAudioSessionController.swift:53: public nonisolated static func voipCategoryOptions(
BaresipAudioSessionController.swift:80: public func configureForVoIP(allowBluetooth: Bool = true, defaultToSpeaker: Bool = false) throws
BaresipAudioSessionController.swift:92: public func activate() async throws
BaresipAudioSessionController.swift:99: public func deactivate() async
BaresipAudioSessionController.swift:126: public func didActivateFromCallKit() async
BaresipAudioSessionController.swift:132: public func didDeactivateFromCallKit() async
BaresipAudioSessionController+Outputs.swift:12: public func setSpeakerEnabled(_ enabled: Bool) throws
BaresipAudioSessionController+Outputs.swift:17: public var currentRoute: BaresipAudioRoute
BaresipAudioSessionController+Outputs.swift:42: public var availableOutputs: [BaresipAudioOutput]
BaresipAudioSessionController+Outputs.swift:65: public var currentOutput: BaresipAudioOutput?
BaresipAudioSessionController+Outputs.swift:84: public func selectOutput(_ output: BaresipAudioOutput) throws
BaresipAudioRoute.swift:4:public enum BaresipAudioRoute: Sendable, Hashable
```

## BaresipKitCallKit (42 declarations)

```
BaresipCallKitAdapter+Push.swift:52: public func reportIncomingCallFromPush(uuid pushedUUID: UUID?, remoteURI: String?, displayName: String?,
BaresipCallKitAdapter+Push.swift:85: public func reportIncomingCallFromPush(uuid: UUID?, remoteURI: String?, displayName: String?,
BaresipCallKitAdapter+Controller.swift:11: public func controls(_ call: BaresipCallID) -> Bool
BaresipCallKitAdapter+Controller.swift:23: public func placeCall(to destination: String, video: Bool) async throws -> BaresipCallID
BaresipCallKitAdapter+Controller.swift:44: public func answer(_ call: BaresipCallID, video: Bool) async throws
BaresipCallKitAdapter+Controller.swift:59: public func end(_ call: BaresipCallID) async throws
BaresipCallKitAdapter+Controller.swift:69: public func setOnHold(_ onHold: Bool, call: BaresipCallID) async throws
BaresipCallKitAdapter+Controller.swift:79: public func setMuted(_ muted: Bool, call: BaresipCallID) async throws
BaresipCallKitAdapter+Controller.swift:88: public func addMuteObserver(_ observer: @escaping @Sendable (BaresipCallID, Bool) -> Void)
BaresipCallKitAdapter+ProviderDelegate.swift:12: public func providerDidReset(_ provider: CXProvider)
BaresipCallKitAdapter+ProviderDelegate.swift:43: public func provider(_ provider: CXProvider, perform action: CXStartCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:77: public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction)
BaresipCallKitAdapter+ProviderDelegate.swift:102: public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:129: public func provider(_ provider: CXProvider, perform action: CXEndCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:149: public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:169: public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:190: public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction)
BaresipCallKitAdapter+ProviderDelegate.swift:206: public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession)
BaresipCallKitAdapter+ProviderDelegate.swift:217: public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession)
BaresipCallKitConfiguration.swift:5:public enum BaresipCallKitError: Error, Sendable, Equatable
BaresipCallKitConfiguration.swift:11:public struct BaresipCallKitConfiguration: Sendable
BaresipCallKitConfiguration.swift:13: public var supportsVideo: Bool
BaresipCallKitConfiguration.swift:15: public var maximumCallsPerCallGroup: Int
BaresipCallKitConfiguration.swift:17: public var iconTemplateImageData: Data?
BaresipCallKitConfiguration.swift:21: public var ringtoneSound: String?
BaresipCallKitConfiguration.swift:23: public var pushInviteTimeout: Duration = .seconds(30)
BaresipCallKitConfiguration.swift:27: public var sendsCameraOnAnswer = true
BaresipCallKitConfiguration.swift:34: public var matchesPushWithoutCaller = true
BaresipCallKitConfiguration.swift:43: public var callUUIDHeader: String?
BaresipCallKitConfiguration.swift:48: public var includesCallsInRecents = true
BaresipCallKitConfiguration.swift:50: public var handleStyle: BaresipHandleStyle = .sipURI
BaresipCallKitConfiguration.swift:59: public init(supportsVideo: Bool = true, maximumCallsPerCallGroup: Int = 1,
BaresipCallKitAdapter.swift:19: public final class BaresipCallKitAdapter: NSObject, @unchecked Sendable
BaresipCallKitAdapter.swift:48: public init(engine: BaresipEngine, configuration: BaresipCallKitConfiguration)
BaresipCallKitAdapter.swift:83: public func setRingtoneSound(_ sound: String?)
BaresipCallKitAdapter.swift:93: public func uuid(for call: BaresipCallID) -> UUID?
BaresipCallKitAdapter.swift:108: public func startOutgoingCall(to destination: String, displayName: String? = nil,
BaresipCallKitAdapter.swift:138: public func answerCall(uuid: UUID) async throws
BaresipCallKitAdapter.swift:150: public func setMuted(_ muted: Bool, uuid: UUID) async throws
BaresipCallKitAdapter.swift:162: public func setHeld(_ onHold: Bool, uuid: UUID) async throws
BaresipCallKitAdapter.swift:173: public func setMuteHandler(_ handler: (@Sendable (BaresipCallID, Bool) -> Void)?)
BaresipCallKitAdapter.swift:182: public func endCall(uuid: UUID) async throws
```

## BaresipKitLiveCommunication (37 declarations)

```
BaresipLiveCommunicationAdapter+Push.swift:36: public func reportIncomingCallFromPush(uuid pushedUUID: UUID?, remoteURI: String?, displayName: String?,
BaresipLiveCommunicationAdapter.swift:25: public final class BaresipLiveCommunicationAdapter: @unchecked Sendable
BaresipLiveCommunicationAdapter.swift:53: public init(engine: BaresipEngine, configuration: BaresipLiveCommunicationConfiguration)
BaresipLiveCommunicationAdapter.swift:88: public func uuid(for call: BaresipCallID) -> UUID?
BaresipLiveCommunicationAdapter.swift:103: public func startOutgoingCall(to destination: String, displayName: String? = nil,
BaresipLiveCommunicationAdapter.swift:132: public func answerCall(uuid: UUID) async throws
BaresipLiveCommunicationAdapter.swift:144: public func setMuted(_ muted: Bool, uuid: UUID) async throws
BaresipLiveCommunicationAdapter.swift:155: public func setHeld(_ onHold: Bool, uuid: UUID) async throws
BaresipLiveCommunicationAdapter.swift:164: public func endCall(uuid: UUID) async throws
BaresipLiveCommunicationConfiguration.swift:6:public enum BaresipLiveCommunicationError: Error, Sendable, Equatable
BaresipLiveCommunicationConfiguration.swift:16:public struct BaresipLiveCommunicationConfiguration: Sendable
BaresipLiveCommunicationConfiguration.swift:18: public var supportsVideo: Bool
BaresipLiveCommunicationConfiguration.swift:20: public var maximumConversationGroups: Int
BaresipLiveCommunicationConfiguration.swift:22: public var maximumConversationsPerConversationGroup: Int
BaresipLiveCommunicationConfiguration.swift:24: public var iconTemplateImageData: Data?
BaresipLiveCommunicationConfiguration.swift:28: public var ringtoneName: String?
BaresipLiveCommunicationConfiguration.swift:30: public var pushInviteTimeout: Duration = .seconds(30)
BaresipLiveCommunicationConfiguration.swift:34: public var sendsCameraOnAnswer = true
BaresipLiveCommunicationConfiguration.swift:40: public var matchesPushWithoutCaller = true
BaresipLiveCommunicationConfiguration.swift:47: public var callUUIDHeader: String?
BaresipLiveCommunicationConfiguration.swift:51: public var includesCallsInRecents = true
BaresipLiveCommunicationConfiguration.swift:53: public var handleStyle: BaresipHandleStyle = .sipURI
BaresipLiveCommunicationConfiguration.swift:63: public init(supportsVideo: Bool = true, maximumConversationGroups: Int = 1,
BaresipLiveCommunicationAdapter+Controller.swift:12: public func controls(_ call: BaresipCallID) -> Bool
BaresipLiveCommunicationAdapter+Controller.swift:24: public func placeCall(to destination: String, video: Bool) async throws -> BaresipCallID
BaresipLiveCommunicationAdapter+Controller.swift:46: public func answer(_ call: BaresipCallID, video: Bool) async throws
BaresipLiveCommunicationAdapter+Controller.swift:62: public func end(_ call: BaresipCallID) async throws
BaresipLiveCommunicationAdapter+Controller.swift:73: public func setOnHold(_ onHold: Bool, call: BaresipCallID) async throws
BaresipLiveCommunicationAdapter+Controller.swift:84: public func setMuted(_ muted: Bool, call: BaresipCallID) async throws
BaresipLiveCommunicationAdapter+Controller.swift:92: public func addMuteObserver(_ observer: @escaping @Sendable (BaresipCallID, Bool) -> Void)
BaresipLiveCommunicationAdapter+Delegate.swift:13: public func conversationManagerDidBegin(_ manager: ConversationManager) {}
BaresipLiveCommunicationAdapter+Delegate.swift:18: public func conversationManagerDidReset(_ manager: ConversationManager)
BaresipLiveCommunicationAdapter+Delegate.swift:49: public func conversationManager(_ manager: ConversationManager,
BaresipLiveCommunicationAdapter+Delegate.swift:57: public func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession)
BaresipLiveCommunicationAdapter+Delegate.swift:68: public func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession)
BaresipLiveCommunicationAdapter+Delegate.swift:81: public func conversationManager(_ manager: ConversationManager, perform action: ConversationAction)
BaresipLiveCommunicationAdapter+Delegate.swift:110: public func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction)
```

## BaresipKitPushKit (27 declarations)

```
BaresipPushKitAdapter.swift:34: public final class BaresipPushKitAdapter: NSObject, PKPushRegistryDelegate, @unchecked Sendable
BaresipPushKitAdapter.swift:43: public typealias IncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) throws -> Void
BaresipPushKitAdapter.swift:50: public typealias AsyncIncomingPushHandler = @Sendable (_ payload: [AnyHashable: Any]) async throws -> Void
BaresipPushKitAdapter.swift:59: public enum Step: Sendable
BaresipPushKitAdapter.swift:72: public typealias ErrorHandler = @Sendable (_ step: Step, _ error: Error) -> Void
BaresipPushKitAdapter.swift:93: public convenience init(engine: BaresipEngine, appID: String, accountID: BaresipAccountID? = nil,
BaresipPushKitAdapter.swift:119: public static func reportingAsynchronously(engine: BaresipEngine, appID: String,
BaresipPushKitAdapter.swift:148: public func setErrorHandler(_ handler: ErrorHandler?)
BaresipPushKitAdapter.swift:157: public func bind(accountID: BaresipAccountID)
BaresipPushKitAdapter.swift:168: public func updateAppID(_ appID: String)
BaresipPushKitAdapter.swift:176: public func updateRemoteToken(_ token: Data)
BaresipPushKitAdapter.swift:185: public func updateAdditionalContactParameters(_ parameters: [BaresipContactParameter])
BaresipPushKitAdapter.swift:197: public var currentTokens: BaresipPushTokens
BaresipPushKitAdapter.swift:207: public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
BaresipPushKitAdapter.swift:219: public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType)
BaresipPushKitAdapter.swift:235: public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
BaresipPushTokens.swift:9:public struct BaresipPushTokens: Sendable, Equatable
BaresipPushTokens.swift:11: public var appID: String
BaresipPushTokens.swift:13: public var remoteToken: Data?
BaresipPushTokens.swift:15: public var voipToken: Data?
BaresipPushTokens.swift:17: public var platform: String
BaresipPushTokens.swift:19: public var silent: Bool
BaresipPushTokens.swift:21: public var timeout: Int
BaresipPushTokens.swift:23: public var channel: String?
BaresipPushTokens.swift:35: public init(appID: String, remoteToken: Data? = nil, voipToken: Data? = nil,
BaresipPushTokens.swift:48: public var combinedToken: String
BaresipPushTokens.swift:60: public var contactParameters: [BaresipContactParameter]
```

## BaresipKitSwiftUI (61 declarations)

```
BaresipPhone.swift:29:public final class BaresipPhone: ObservableObject
BaresipPhone.swift:31: public let engine: BaresipEngine
BaresipPhone.swift:36: @Published public private(set) var registrations: [BaresipAccountID: BaresipRegistrationState] = [:]
BaresipPhone.swift:39: @Published public private(set) var calls: [BaresipPhoneCall] = []
BaresipPhone.swift:46: @Published public private(set) var activeCall: BaresipPhoneCall?
BaresipPhone.swift:51: public var callController: BaresipCallController?
BaresipPhone.swift:56: public var resumesHeldCallWhenActiveCallEnds = true
BaresipPhone.swift:67: public init(engine: BaresipEngine, callController: BaresipCallController? = nil)
BaresipPhone.swift:74: public var incomingCall: BaresipPhoneCall?
BaresipPhone.swift:85: public func run() async
BaresipPhone.swift:97: public func call(_ id: BaresipCallID) -> BaresipPhoneCall?
BaresipPhone.swift:115: public func makeCall(to destination: String, accountID: BaresipAccountID? = nil,
BaresipPhone.swift:144: public func makeActive(_ call: BaresipPhoneCall) async throws
BaresipSelfView.swift:8: public extension BaresipCallVideo
BaresipSelfView.swift:42: public struct BaresipSelfView: View
BaresipSelfView.swift:55: public init(call: BaresipPhoneCall, size: CGSize = CGSize(width: 100, height: 140),
BaresipSelfView.swift:64: public var body: some View
BaresipPhoneCall+DTMF.swift:14: public func sendDTMF(_ digits: String, expectingReply reply: Character,
BaresipPhoneCall+DTMF.swift:59: public nonisolated static func userPart(of uri: String) -> String
BaresipPhoneCall+DTMF.swift:75:public enum BaresipDTMFReply: Sendable, Equatable
BaresipPhone+Messages.swift:11: public func isPeer(_ address: String) -> Bool
BaresipPhone+Messages.swift:24: public nonisolated static func samePeer(_ first: String, _ second: String) -> Bool
BaresipPhone+Messages.swift:41: public func call(withPeer address: String) -> BaresipPhoneCall?
BaresipPhoneCall.swift:14:public final class BaresipPhoneCall: ObservableObject, Identifiable
BaresipPhoneCall.swift:16: public let id: BaresipCallID
BaresipPhoneCall.swift:19: public let startedAt = Date()
BaresipPhoneCall.swift:22: @Published public private(set) var state: BaresipCallState
BaresipPhoneCall.swift:26: @Published public private(set) var error: BaresipError?
BaresipPhoneCall.swift:29: @Published public private(set) var remoteURI = ""
BaresipPhoneCall.swift:32: @Published public private(set) var remoteDisplayName = ""
BaresipPhoneCall.swift:35: @Published public private(set) var isOutgoing = false
BaresipPhoneCall.swift:40: @Published public private(set) var isDirectionKnown = false
BaresipPhoneCall.swift:43: @Published public private(set) var hasVideo = false
BaresipPhoneCall.swift:46: @Published public private(set) var isMuted = false
BaresipPhoneCall.swift:49: @Published public private(set) var audioDirection: BaresipMediaDirection = .inactive
BaresipPhoneCall.swift:52: @Published public private(set) var videoDirection: BaresipMediaDirection = .inactive
BaresipPhoneCall.swift:55: @Published public private(set) var audioCodec = ""
BaresipPhoneCall.swift:58: @Published public private(set) var videoCodec = ""
BaresipPhoneCall.swift:61: @Published public private(set) var connectedAt: Date?
BaresipPhoneCall.swift:67: @Published public private(set) var isSendingVideo = false
BaresipPhoneCall.swift:70: @Published public private(set) var camera: BaresipCameraPosition
BaresipPhoneCall.swift:73: @Published public private(set) var isPreviewing = false
BaresipPhoneCall.swift:76: @Published public private(set) var receivedDTMF = ""
BaresipPhoneCall.swift:81: public let engine: BaresipEngine
BaresipPhoneCall.swift:95: public var isRinging: Bool
BaresipPhoneCall.swift:101: public var isOnHold: Bool
BaresipPhoneCall.swift:106: public var isHeldByRemote: Bool
BaresipPhoneCall.swift:111: public var isConnected: Bool
BaresipPhoneCall.swift:116: public var isReceivingVideo: Bool
BaresipPhoneCall.swift:121: public var displayName: String
BaresipPhoneCall.swift:134: public func answer(video: Bool = false, audio: Bool = true) async throws
BaresipPhoneCall.swift:155: public func startPreview(video: Bool = true, audio: Bool = true) async throws
BaresipPhoneCall.swift:165: public func reject() async throws
BaresipPhoneCall.swift:176: public func hangUp() async throws
BaresipPhoneCall.swift:191: public func setMuted(_ muted: Bool) async throws
BaresipPhoneCall.swift:204: public func setOnHold(_ onHold: Bool) async throws
BaresipPhoneCall.swift:218: public func setVideoEnabled(_ enabled: Bool) async throws
BaresipPhoneCall.swift:234: public func setCamera(_ position: BaresipCameraPosition) async throws
BaresipPhoneCall.swift:242: public func switchCamera() async throws
BaresipPhoneCall.swift:250: public func sendDTMF(_ digits: String) async throws
BaresipPhoneCall.swift:258: public func refresh()
```

## BaresipKitVideo (24 declarations)

```
BaresipVideoFrame+Image.swift:20: public func makeImage(context: CIContext = CIContext(options: [.cacheIntermediates: false])) -> CGImage?
BaresipCallVideo.swift:22: public struct BaresipCallVideo: UIViewRepresentable
BaresipCallVideo.swift:24: public enum Source: Sendable, Hashable
BaresipCallVideo.swift:49: public init(engine: BaresipEngine, callID: BaresipCallID, source: Source = .remote,
BaresipCallVideo.swift:61: public final class Coordinator
BaresipCallVideo.swift:79: public func makeCoordinator() -> Coordinator
BaresipCallVideo.swift:87: public func makeUIView(context: Context) -> BaresipVideoView
BaresipCallVideo.swift:100: public func updateUIView(_ uiView: BaresipVideoView, context: Context)
BaresipCallVideo.swift:110: public static func dismantleUIView(_ uiView: BaresipVideoView, coordinator: Coordinator)
BaresipVideo.swift:6:public typealias BaresipVideoFrame = BaresipKit.BaresipVideoFrame
BaresipVideo.swift:8:public typealias BaresipVideoRenderer = BaresipKit.BaresipVideoRenderer
BaresipVideo.swift:10:public typealias BaresipPixelFormat = BaresipKit.BaresipPixelFormat
BaresipVideo.swift:18:public final class BaresipVideoFrameRelay: BaresipVideoRenderer, @unchecked Sendable
BaresipVideo.swift:29: public init(onFrame: (@Sendable (BaresipVideoFrame) -> Void)? = nil,
BaresipVideo.swift:40: public func setHandlers(onFrame: (@Sendable (BaresipVideoFrame) -> Void)?,
BaresipVideo.swift:51: public func render(_ frame: BaresipVideoFrame)
BaresipVideo.swift:61: public func didChangeSize(width: Int, height: Int)
BaresipVideoView.swift:19: public final class BaresipVideoView: UIView
BaresipVideoView.swift:35: public required init?(coder: NSCoder)
BaresipVideoView.swift:54: public var videoGravity: AVLayerVideoGravity
BaresipVideoView.swift:60: public var renderer: BaresipVideoRenderer
BaresipVideoView.swift:65: public func flush()
BaresipVideoView.swift:75: public var currentFrame: BaresipVideoFrame?
BaresipVideoView.swift:83: public func snapshot() -> CGImage?
```

