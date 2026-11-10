import Foundation

/// Writes log lines to daily files, so logs of a call can be shared afterwards.
///
/// One file per day, in the given directory, with the oldest files beyond `daysToKeep`
/// removed and a file beyond `maxFileSize` truncated. Lines are written on a serial queue
/// straight to the file, so nothing is lost when the app is suspended or killed; the files
/// can be written while the device is locked, since calls can arrive then too.
public final class BaresipFileLog: @unchecked Sendable {
    // SAFETY: `handle` and `currentDay` are touched only on `queue`.

    private let queue = DispatchQueue(label: "baresipkit.filelog")
    private let directory: URL
    private let maxFileSize: UInt64
    private let daysToKeep: Int
    private var handle: FileHandle?
    private var currentDay = ""

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Creates a file log that writes into `directory`, creating it if needed.
    ///
    /// - Parameters:
    ///   - directory: Where log files are written. Defaults to a `Logs` folder in the app's
    ///     Application Support directory.
    ///   - maxFileSize: The size, in bytes, beyond which a day's file is truncated and
    ///     restarted. Defaults to 50 MB.
    ///   - daysToKeep: The number of most recent daily files kept; older ones are removed.
    ///     Defaults to 7.
    public init(directory: URL? = nil, maxFileSize: UInt64 = 50 * 1024 * 1024, daysToKeep: Int = 7) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let name = Bundle.main.bundleIdentifier ?? "BaresipKit"
            self.directory = support.appendingPathComponent(name, isDirectory: true)
                .appendingPathComponent("Logs", isDirectory: true)
        }
        self.maxFileSize = maxFileSize
        self.daysToKeep = daysToKeep
        queue.async { [self] in
            try? FileManager.default.createDirectory(
                at: self.directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = self.directory
            try? url.setResourceValues(values)
            pruneOldFiles()
        }
    }

    /// Appends a line, with the time and an optional tag.
    ///
    /// - Parameters:
    ///   - message: The text to write.
    ///   - tag: A short tag shown next to the time. Defaults to `"app"`.
    public func write(_ message: String, tag: String = "app") {
        let now = Date()
        queue.async { [self] in
            let line = "\(timeFormatter.string(from: now)) [\(tag)] \(message)"
            let text = line.hasSuffix("\n") ? line : line + "\n"
            fileHandle(for: now)?.write(Data(text.utf8))
        }
    }

    /// Returns a log handler for ``BaresipEngine/setLogHandler(_:)`` that writes to the file
    /// and passes each entry on to `next`, for example ``BaresipOSLog/handler(subsystem:)``.
    ///
    /// - Parameter next: A handler to forward every entry to, or `nil`.
    public func handler(forwardingTo next: BaresipLogHandler? = nil) -> BaresipLogHandler {
        { [self] entry in
            write(entry.message.trimmingCharacters(in: .newlines),
                  tag: "\(entry.domain) \(entry.level)")
            next?(entry)
        }
    }

    /// The log files, newest first. Waits for lines still being written.
    public func files() -> [URL] {
        queue.sync {
            try? handle?.synchronize()
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            )) ?? []
            return urls.filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }
    }

    private func fileHandle(for date: Date) -> FileHandle? {
        let day = dayFormatter.string(from: date)
        if day != currentDay || handle == nil || isTooLarge() {
            try? handle?.close()
            handle = nil
            currentDay = day
            let url = directory.appendingPathComponent("BaresipKit-\(day).log")
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(
                    atPath: url.path, contents: nil,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                )
            } else if isTooLarge(url) {
                try? FileManager.default.removeItem(at: url)
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
            pruneOldFiles()
        }
        return handle
    }

    private func isTooLarge(_ url: URL? = nil) -> Bool {
        if let url {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
            return size > maxFileSize
        }
        guard let handle, let offset = try? handle.offset() else { return false }
        return offset > maxFileSize
    }

    private func pruneOldFiles() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        let logs = urls.filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in logs.dropFirst(daysToKeep) {
            try? FileManager.default.removeItem(at: old)
        }
    }
}
