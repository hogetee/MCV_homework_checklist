import Foundation

enum AssignmentStore {
    static let suiteName = "P5Q772DRZW.com.mcvnot.shared"
    private static let key = "assignments.v1"
    private static let updatedKey = "lastSync.v1"
    private static let loginKey = "needsLogin.v1"

    static func load() -> [Assignment] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let assignments = try? JSONDecoder().decode([Assignment].self, from: data) else { return [] }
        return assignments
    }

    static func save(_ assignments: [Assignment], source: AssignmentSource = .courseVille) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(assignments) else { return }
        defaults.set(data, forKey: key)
        defaults.set(Date(), forKey: syncKey(source))
        defaults.set(false, forKey: authKey(source))
    }

    static func lastSync() -> Date? {
        let sources: [AssignmentSource] = classDeeDeeEnabled() ? [.courseVille, .classDeeDee] : [.courseVille]
        return sources.compactMap { lastSync(for: $0) }.min()
    }

    static func lastSync(for source: AssignmentSource) -> Date? {
        UserDefaults(suiteName: suiteName)?.object(forKey: syncKey(source)) as? Date
    }

    static func needsLogin() -> Bool {
        !loginSources().isEmpty
    }

    static func needsLogin(for source: AssignmentSource) -> Bool {
        UserDefaults(suiteName: suiteName)?.bool(forKey: authKey(source)) ?? false
    }

    static func loginSources() -> [AssignmentSource] {
        AssignmentSource.allCases.filter {
            ($0 == .courseVille || classDeeDeeEnabled()) && needsLogin(for: $0)
        }
    }

    static func setNeedsLogin(_ value: Bool, source: AssignmentSource = .courseVille) {
        UserDefaults(suiteName: suiteName)?.set(value, forKey: authKey(source))
    }

    static func classDeeDeeEnabled() -> Bool {
        UserDefaults(suiteName: suiteName)?.bool(forKey: "classDeeDee.enabled.v1") ?? false
    }

    static func enableClassDeeDee() {
        UserDefaults(suiteName: suiteName)?.set(true, forKey: "classDeeDee.enabled.v1")
    }

    private static func syncKey(_ source: AssignmentSource) -> String {
        source == .courseVille ? updatedKey : "classDeeDee.lastSync.v1"
    }

    private static func authKey(_ source: AssignmentSource) -> String {
        source == .courseVille ? loginKey : "classDeeDee.needsLogin.v1"
    }
}
