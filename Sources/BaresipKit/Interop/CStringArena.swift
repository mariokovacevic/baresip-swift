import Foundation
import BaresipKitCore

final class CStringArena {
    private var duplicatedStrings: [UnsafeMutablePointer<CChar>] = []
    private var buffers: [UnsafeMutableRawPointer] = []

    deinit {
        for string in duplicatedStrings {
            free(string)
        }
        for buffer in buffers {
            buffer.deallocate()
        }
    }

    func cString(_ value: String?) -> UnsafePointer<CChar>? {
        guard let value, let copy = strdup(value) else { return nil }
        duplicatedStrings.append(copy)
        return UnsafePointer(copy)
    }

    func cStringArray(_ values: [String]) -> UnsafePointer<UnsafePointer<CChar>?>? {
        guard !values.isEmpty else { return nil }
        let buffer = allocate(UnsafePointer<CChar>?.self, count: values.count)
        for (index, value) in values.enumerated() {
            buffer[index] = cString(value)
        }
        return UnsafePointer(buffer)
    }

    func bytes(_ data: Data?) -> (pointer: UnsafePointer<CChar>?, count: Int) {
        guard let data, !data.isEmpty else { return (nil, 0) }
        let buffer = allocate(CChar.self, count: data.count + 1)
        // SAFETY: buffer holds data.count + 1 bytes; the copy writes data.count and the terminator fills the last.
        _ = data.withUnsafeBytes { raw in
            raw.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: data.count))
        }
        buffer[data.count] = 0
        return (UnsafePointer(buffer), data.count)
    }

    func contactParameters(_ parameters: [BaresipContactParameter]) -> UnsafePointer<bsk_contact_param>? {
        guard !parameters.isEmpty else { return nil }
        let buffer = allocate(bsk_contact_param.self, count: parameters.count)
        for (index, parameter) in parameters.enumerated() {
            buffer[index] = bsk_contact_param(name: cString(parameter.name), value: cString(parameter.value))
        }
        return UnsafePointer(buffer)
    }

    func turnServers(_ servers: [BaresipTURNServer]) -> UnsafePointer<bsk_turn_server>? {
        guard !servers.isEmpty else { return nil }
        let buffer = allocate(bsk_turn_server.self, count: servers.count)
        for (index, server) in servers.enumerated() {
            buffer[index] = bsk_turn_server(uri: cString(server.uri),
                                            username: cString(server.username),
                                            password: cString(server.password))
        }
        return UnsafePointer(buffer)
    }

    private func allocate<T>(_ type: T.Type, count: Int) -> UnsafeMutablePointer<T> {
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: count)
        buffers.append(UnsafeMutableRawPointer(buffer))
        return buffer
    }
}

func string<T>(fromCArray tuple: T) -> String {
    // SAFETY: the C ABI declares these fields as fixed-size char arrays that the core always NUL-terminates.
    withUnsafeBytes(of: tuple) { raw in
        let length = raw.firstIndex(of: 0) ?? raw.count
        return String(decoding: UnsafeRawBufferPointer(rebasing: raw[0..<length]), as: UTF8.self)
    }
}

extension Duration {
    var wholeSeconds: UInt32 {
        UInt32(clamping: components.seconds)
    }

    var wholeMilliseconds: UInt32 {
        let attosecondsPerMillisecond: Int64 = 1_000_000_000_000_000
        return UInt32(clamping: components.seconds * 1000 + components.attoseconds / attosecondsPerMillisecond)
    }
}

func string(fromNullTerminated buffer: [CChar]) -> String {
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}
