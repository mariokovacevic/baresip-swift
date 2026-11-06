import Foundation
import BaresipKitCore

final class CStringArena {
    private var pointers: [UnsafeMutableRawPointer] = []

    deinit {
        for p in pointers {
            free(p)
        }
    }

    func cString(_ value: String?) -> UnsafePointer<CChar>? {
        guard let value else { return nil }
        guard let dup = strdup(value) else { return nil }
        pointers.append(UnsafeMutableRawPointer(dup))
        return UnsafePointer(dup)
    }

    func cStringArray(_ values: [String]) -> UnsafePointer<UnsafePointer<CChar>?>? {
        guard !values.isEmpty else { return nil }
        let buffer = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: values.count)
        for (i, v) in values.enumerated() {
            buffer[i] = cString(v)
        }
        pointers.append(UnsafeMutableRawPointer(buffer))
        return UnsafePointer(buffer)
    }

    func bytes(_ data: Data?) -> (UnsafePointer<CChar>?, Int) {
        guard let data, !data.isEmpty else { return (nil, 0) }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: data.count + 1)
        data.withUnsafeBytes { raw in
            raw.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: data.count))
        }
        buffer[data.count] = 0
        pointers.append(UnsafeMutableRawPointer(buffer))
        return (UnsafePointer(buffer), data.count)
    }

    func contactParams(_ params: [ContactParameter]) -> UnsafePointer<bsk_contact_param>? {
        guard !params.isEmpty else { return nil }
        let buffer = UnsafeMutablePointer<bsk_contact_param>.allocate(capacity: params.count)
        for (i, p) in params.enumerated() {
            buffer[i] = bsk_contact_param(name: cString(p.name), value: cString(p.value))
        }
        pointers.append(UnsafeMutableRawPointer(buffer))
        return UnsafePointer(buffer)
    }

    func turnServers(_ servers: [TURNServer]) -> UnsafePointer<bsk_turn_server>? {
        guard !servers.isEmpty else { return nil }
        let buffer = UnsafeMutablePointer<bsk_turn_server>.allocate(capacity: servers.count)
        for (i, s) in servers.enumerated() {
            buffer[i] = bsk_turn_server(uri: cString(s.uri),
                                        username: cString(s.username),
                                        password: cString(s.password))
        }
        pointers.append(UnsafeMutableRawPointer(buffer))
        return UnsafePointer(buffer)
    }
}

@inline(__always)
func stringFromCArray<T>(_ tuple: T) -> String {
    withUnsafeBytes(of: tuple) { raw -> String in
        let bytes = raw.bindMemory(to: UInt8.self)
        let length = bytes.firstIndex(of: 0) ?? bytes.count
        return String(decoding: UnsafeRawBufferPointer(rebasing: raw[0..<length]), as: UTF8.self)
    }
}

extension bsk_error {
    var isOK: Bool { status == BSK_OK }
}
