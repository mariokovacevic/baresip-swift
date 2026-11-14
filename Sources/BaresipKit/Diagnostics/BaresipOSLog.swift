import os

/// Ready-made log handlers that forward engine logs to the unified logging system.
public enum BaresipOSLog {
    /// Returns a handler that writes each entry to `os.Logger`, one category per domain.
    ///
    /// The core removes passwords, digest responses and push tokens from its messages, but they
    /// still contain SIP URIs, IP addresses, display names and headers. Messages are therefore
    /// logged as private by default: the unified logging system shows them on a device that is
    /// connected to a debugger, and `<private>` elsewhere. Pass `publicMessages: true` to log them
    /// in full, for example in a debug build.
    ///
    /// ```swift
    /// engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.app"))
    /// ```
    ///
    /// - Parameters:
    ///   - subsystem: The subsystem name shown in Console.
    ///   - publicMessages: Whether messages are logged with public privacy.
    /// - Returns: A handler for ``BaresipEngine/setLogHandler(_:)``.
    public static func handler(subsystem: String = "BaresipKit", publicMessages: Bool = false) -> BaresipLogHandler {
        let core = Logger(subsystem: subsystem, category: "core")
        let sip = Logger(subsystem: subsystem, category: "sip")
        let media = Logger(subsystem: subsystem, category: "media")
        return { entry in
            let logger: Logger = switch entry.domain {
            case .core: core
            case .sip: sip
            case .media: media
            }
            let type: OSLogType = switch entry.level {
            case .debug: .debug
            case .info: .info
            case .warning: .default
            case .error: .error
            }
            if publicMessages {
                logger.log(level: type, "\(entry.message, privacy: .public)")
            } else {
                logger.log(level: type, "\(entry.message, privacy: .private)")
            }
        }
    }
}
