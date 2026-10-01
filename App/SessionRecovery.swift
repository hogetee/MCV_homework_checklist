import Foundation

@MainActor
enum SessionRecovery {
    /// A stale login response gets one page refresh and one new read.
    /// A network error propagates so cached work is kept without a login alert.
    static func fetch<Value>(
        read: () async throws -> Value,
        needsLogin: (Value) -> Bool,
        reload: () async throws -> Bool
    ) async throws -> Value {
        let first = try await read()
        guard needsLogin(first), try await reload() else { return first }
        return try await read()
    }
}
