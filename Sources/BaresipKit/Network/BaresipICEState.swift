/// The state of ICE for a call.
public enum BaresipICEState: Int, Sendable, Codable {
    /// ICE is not used.
    case none = 0
    /// Candidates are being gathered.
    case gathering = 1
    /// Connectivity checks are running.
    case checking = 2
    /// A candidate pair was selected.
    case connected = 3
    /// No candidate pair worked.
    case failed = 4
}
