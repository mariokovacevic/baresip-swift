import BaresipKitCore

extension CoreEngine {
    func makeCall(account: BaresipAccountID?, destination: String, video: Bool) throws -> BaresipCallID {
        var id: UInt64 = 0
        try Self.withArena { arena in
            try Self.check {
                bsk_call_make(raw, account?.rawValue ?? 0, arena.cString(destination), video, &id, &$0)
            }
        }
        return BaresipCallID(rawValue: id)
    }

    func answer(_ call: BaresipCallID, video: Bool) throws {
        try Self.check { bsk_call_answer(raw, call.rawValue, video, &$0) }
    }

    func sendProgress(_ call: BaresipCallID, earlyVideo: Bool) throws {
        try Self.check { bsk_call_progress(raw, call.rawValue, earlyVideo, &$0) }
    }

    func reject(_ call: BaresipCallID, statusCode: UInt16, reason: String?) throws {
        try Self.withArena { arena in
            try Self.check { bsk_call_reject(raw, call.rawValue, statusCode, arena.cString(reason), &$0) }
        }
    }

    func hangup(_ call: BaresipCallID) throws {
        try Self.check { bsk_call_hangup(raw, call.rawValue, &$0) }
    }

    func setHold(_ call: BaresipCallID, _ hold: Bool) throws {
        try Self.check { bsk_call_hold(raw, call.rawValue, hold, &$0) }
    }

    func setActive(_ call: BaresipCallID) throws {
        try Self.check { bsk_call_set_active(raw, call.rawValue, &$0) }
    }

    func sendDTMF(_ call: BaresipCallID, digits: String, duration: Duration, gap: Duration) throws {
        try Self.withArena { arena in
            try Self.check {
                bsk_call_send_dtmf(raw, call.rawValue, arena.cString(digits),
                                   duration.wholeMilliseconds, gap.wholeMilliseconds, &$0)
            }
        }
    }

    func transfer(_ call: BaresipCallID, to target: String) throws {
        try Self.withArena { arena in
            try Self.check { bsk_call_transfer(raw, call.rawValue, arena.cString(target), &$0) }
        }
    }

    func transferAttended(_ call: BaresipCallID, to target: BaresipCallID) throws {
        try Self.check { bsk_call_transfer_attended(raw, call.rawValue, target.rawValue, &$0) }
    }

    func callInfo(_ call: BaresipCallID) throws -> BaresipCallInfo {
        var info = bsk_call_info()
        try Self.checkStatus(bsk_call_get_info(raw, call.rawValue, &info))
        return BaresipCallInfo(info)
    }

    func callStatistics(_ call: BaresipCallID) throws -> BaresipCallStatistics {
        var statistics = bsk_call_statistics()
        try Self.checkStatus(bsk_call_get_statistics(raw, call.rawValue, &statistics))
        return BaresipCallStatistics(statistics)
    }

    func activeCalls() -> [BaresipCallID] {
        let count = bsk_call_list(raw, nil, 0)
        guard count > 0 else { return [] }
        var ids = [UInt64](repeating: 0, count: count)
        let written = bsk_call_list(raw, &ids, ids.count)
        return ids.prefix(min(written, ids.count)).map { BaresipCallID(rawValue: $0) }
    }
}
