import Foundation
import Security
import WebKit

/// Keeps this app's ClassDeeDee cookies across launches. Server expiry still applies.
@MainActor
final class SessionCookieStore: NSObject, WKHTTPCookieStoreObserver {
    private static let service = "com.mcvnot.app.classdeedee.session"
    private static let account = "webkit-cookies"
    private static let domains: Set<String> = [
        "classdeedee.cloud.cp.eng.chula.ac.th", "account.it.chula.ac.th"
    ]
    private let store: WKHTTPCookieStore
    private var saveTask: Task<Void, Never>?
    private(set) var lastStatus: OSStatus = errSecSuccess

    init(store: WKHTTPCookieStore) {
        self.store = store
        super.init()
        store.add(self)
    }

    static func restore(into store: WKHTTPCookieStore) async {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let records = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else { return }
        for record in records {
            let properties = Dictionary(uniqueKeysWithValues: record.map { (HTTPCookiePropertyKey($0.key), $0.value) })
            guard let cookie = HTTPCookie(properties: properties), accepts(cookie),
                  cookie.expiresDate.map({ $0 > .now }) ?? true else { continue }
            await store.setCookie(cookie)
        }
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        saveTask?.cancel()
        saveTask = Task { await persist() }
    }

    @discardableResult
    func persist() async -> OSStatus {
        let cookies = await store.allCookies()
        guard !Task.isCancelled else { return lastStatus }
        let records = cookies.filter(Self.accepts).compactMap { cookie -> [String: Any]? in
            guard let properties = cookie.properties else { return nil }
            var record: [String: Any] = [:]
            for (key, value) in properties {
                if let url = value as? URL { record[key.rawValue] = url.absoluteString }
                else if value is String || value is NSNumber || value is Date {
                    record[key.rawValue] = value
                }
            }
            return record
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: records, format: .binary, options: 0)
        else { return errSecParam }
        let query = Self.keychainQuery
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        lastStatus = status
        return status
    }

    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private static func accepts(_ cookie: HTTPCookie) -> Bool {
        domains.contains(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }
}
