import os

/// Ready-made log handlers that forward engine logs to the unified logging system.
public enum BaresipOSLog {
    /// Returns a handler that writes each entry to `os.Logger`, one category per domain.
    ///
    /// Messages are logged with public privacy because the core has already redacted secrets.
    ///
    /// ```swift
    /// engine.setLogHandler(BaresipOSLog.handler(subsystem: "com.example.app"))
    /// ```
    ///
    /// - Parameter subsystem: The subsystem name shown in Console.
    /// - Returns: A handler for ``BaresipEngine/setLogHandler(_:)``.
    public static func handler(subsystem: String = "BaresipKit") -> BaresipLogHandler {
        let core = Logger(subsystem: subsystem, category: "core")
        let sip = Logger(subsystem: subsystem, category: "sip")
        let media = Logger(subsystem: subsystem, category: "media")
        return { entry in
            let logger: Logger
            switch entry.domain {
            case .core: logger = core
            case .sip: logger = sip
            case .media: logger = media
            }
            switch entry.level {
            case .debug: logger.debug("\(entry.message, privacy: .public)")
            case .info: logger.info("\(entry.message, privacy: .public)")
            case .warning: logger.warning("\(entry.message, privacy: .public)")
            case .error: logger.error("\(entry.message, privacy: .public)")
            }
        }
    }
}
