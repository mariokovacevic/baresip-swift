import XCTest
@testable import BaresipKit

final class FileLogTests: XCTestCase {
    private func makeDirectory() -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("FileLogTests-\(UUID().uuidString)", isDirectory: true)
    }

    func testWriteCreatesALogFile() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = BaresipFileLog(directory: directory)
        log.write("hello")
        let files = log.files()
        XCTAssertEqual(files.count, 1)
        let text = (try? String(contentsOf: files[0], encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("[app] hello"))
    }

    func testWriteWithTag() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = BaresipFileLog(directory: directory)
        log.write("entry", tag: "sip")
        let text = (try? String(contentsOf: log.files()[0], encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("[sip] entry"))
    }

    func testOversizedFileIsTruncated() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = BaresipFileLog(directory: directory, maxFileSize: 64)
        for index in 0 ..< 50 {
            log.write("line number \(index) with some padding to grow the file quickly")
        }
        // The file is rewritten once it grows past maxFileSize, so it never grows unbounded.
        let files = log.files()
        XCTAssertEqual(files.count, 1)
    }

    func testOldFilesBeyondDaysToKeepAreRemoved() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for day in ["2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04"] {
            let url = directory.appendingPathComponent("BaresipKit-\(day).log")
            FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        }
        let log = BaresipFileLog(directory: directory, daysToKeep: 2)
        log.write("trigger pruning")
        let remaining = log.files().map(\.lastPathComponent).sorted()
        XCTAssertEqual(remaining.count, 2)
    }

    func testHandlerForwardsToNext() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = BaresipFileLog(directory: directory)
        let expectation = expectation(description: "forwarded")
        let handler = log.handler { entry in
            XCTAssertEqual(entry.message, "forwarded message")
            expectation.fulfill()
        }
        handler(BaresipLogEntry(level: .info, domain: .core, message: "forwarded message"))
        wait(for: [expectation], timeout: 1)
        let text = (try? String(contentsOf: log.files()[0], encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("forwarded message"))
    }
}
