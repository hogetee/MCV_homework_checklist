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

    static func save(_ assignments: [Assignment]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(assignments) else { return }
        defaults.set(data, forKey: key)
        defaults.set(Date(), forKey: updatedKey)
        defaults.set(false, forKey: loginKey)
    }

    static func lastSync() -> Date? {
        UserDefaults(suiteName: suiteName)?.object(forKey: updatedKey) as? Date
    }

    static func needsLogin() -> Bool {
        UserDefaults(suiteName: suiteName)?.bool(forKey: loginKey) ?? false
    }

    static func setNeedsLogin(_ value: Bool) {
        UserDefaults(suiteName: suiteName)?.set(value, forKey: loginKey)
    }
}
