import Foundation
import BaresipKit

/// The app's log file: every log line from launch on, one file per day in Library/Logs, so the
/// logs of a call can be shared from the Log screen.
enum FileLog {
    static let shared = BaresipFileLog(
        directory: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
    )
}
