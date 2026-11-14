import Foundation

enum IncomingPushReport {
    struct Failure: @unchecked Sendable {
        let error: Error
    }

    @discardableResult
    static func deliver(_ payload: [AnyHashable: Any], to handler: ([AnyHashable: Any]) throws -> Void,
                        orReportPlaceholder reportPlaceholder: () -> Void) -> Error? {
        do {
            try handler(payload)
            return nil
        } catch {
            reportPlaceholder()
            return error
        }
    }

    static func deliver(within deadline: Duration,
                        _ handler: @escaping @Sendable () async throws -> Void) async -> Failure? {
        await withCheckedContinuation { continuation in
            let race = FirstOutcome(continuation)
            race.add(Task {
                do {
                    try await handler()
                    race.finish(nil)
                } catch {
                    race.finish(Failure(error: error))
                }
            })
            race.add(Task {
                try? await Task.sleep(for: deadline)
                race.finish(Failure(error: BaresipPushKitError.reportTimedOut))
            })
        }
    }

    private final class FirstOutcome: @unchecked Sendable {
        private typealias Pending = (CheckedContinuation<Failure?, Never>?, [Task<Void, Never>])

        private let lock = NSLock()
        private var continuation: CheckedContinuation<Failure?, Never>?
        private var tasks: [Task<Void, Never>] = []

        init(_ continuation: CheckedContinuation<Failure?, Never>) {
            self.continuation = continuation
        }

        func add(_ task: Task<Void, Never>) {
            let finished = lock.withLock { () -> Bool in
                guard continuation != nil else { return true }
                tasks.append(task)
                return false
            }
            if finished {
                task.cancel()
            }
        }

        func finish(_ outcome: Failure?) {
            let (waiter, running) = lock.withLock { () -> Pending in
                defer {
                    continuation = nil
                    tasks.removeAll()
                }
                return (continuation, tasks)
            }
            guard let waiter else { return }
            for task in running {
                task.cancel()
            }
            waiter.resume(returning: outcome)
        }
    }
}
