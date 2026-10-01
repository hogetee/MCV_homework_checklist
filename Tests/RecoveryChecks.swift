import Foundation

@main
struct RecoveryChecks {
    struct Response { let authRequired: Bool }
    enum Failure: Error { case offline, navigationTimeout }

    @MainActor
    static func main() async throws {
        var reads = 0, reloads = 0
        let valid = try await SessionRecovery.fetch(
            read: { reads += 1; return Response(authRequired: false) },
            needsLogin: { $0.authRequired },
            reload: { reloads += 1; return true })
        precondition(!valid.authRequired && reads == 1 && reloads == 0)

        reads = 0; reloads = 0
        let recovered = try await SessionRecovery.fetch(
            read: { reads += 1; return Response(authRequired: reads == 1) },
            needsLogin: { $0.authRequired },
            reload: { reloads += 1; return true })
        precondition(!recovered.authRequired && reads == 2 && reloads == 1)

        reads = 0; reloads = 0
        let expired = try await SessionRecovery.fetch(
            read: { reads += 1; return Response(authRequired: true) },
            needsLogin: { $0.authRequired },
            reload: { reloads += 1; return true })
        precondition(expired.authRequired && reads == 2 && reloads == 1)

        reads = 0; reloads = 0
        let signInPage = try await SessionRecovery.fetch(
            read: { reads += 1; return Response(authRequired: true) },
            needsLogin: { $0.authRequired },
            reload: { reloads += 1; return false })
        precondition(signInPage.authRequired && reads == 1 && reloads == 1)

        reads = 0; reloads = 0
        do {
            _ = try await SessionRecovery.fetch(
                read: { () -> Response in reads += 1; throw Failure.offline },
                needsLogin: { $0.authRequired },
                reload: { reloads += 1; return true })
            preconditionFailure("An offline error must not become a login result")
        } catch Failure.offline {}
        precondition(reads == 1 && reloads == 0)

        reads = 0; reloads = 0
        do {
            _ = try await SessionRecovery.fetch(
                read: { reads += 1; return Response(authRequired: true) },
                needsLogin: { $0.authRequired },
                reload: { reloads += 1; throw Failure.navigationTimeout })
            preconditionFailure("A navigation timeout must keep the last cached work")
        } catch Failure.navigationTimeout {}
        precondition(reads == 1 && reloads == 1)
        reads = 0; reloads = 0
        do {
            _ = try await SessionRecovery.fetch(
                read: { () -> Response in
                    reads += 1
                    if reads == 2 { throw Failure.offline }
                    return Response(authRequired: true)
                },
                needsLogin: { $0.authRequired },
                reload: { reloads += 1; return true })
            preconditionFailure("A failed second read must not become a confirmed login failure")
        } catch Failure.offline {}
        precondition(reads == 2 && reloads == 1)
        print("Recovery checks passed")
    }
}
