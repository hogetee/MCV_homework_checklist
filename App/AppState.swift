import AppKit
import Combine
import Foundation
import Security
import UserNotifications
import WebKit
import WidgetKit

@MainActor
final class AppState: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var assignments: [Assignment] = AssignmentStore.load()
    @Published private(set) var lastSync: Date? = AssignmentStore.lastSync()
    @Published private(set) var isSyncing = false
    @Published private(set) var loginSources = AssignmentStore.loginSources()
    @Published private(set) var classDeeDeeEnabled = AssignmentStore.classDeeDeeEnabled()
    @Published var message = "เข้าสู่ระบบเพื่อซิงก์การบ้าน"
    @Published var showLogin = false
    @Published var loginSource = AssignmentSource.courseVille

    let webView: WKWebView
    let classDeeDeeWebView: WKWebView
    private var refreshTimer: Timer?
    private var cookieSession: SessionCookieStore?
    private var syncRequested = false
    private var sessionPageReload: SessionPageReload?

    var needsLogin: Bool { !loginSources.isEmpty }
    var loginMessage: String { loginSources.map(\.name).joined(separator: ", ") + " · ต้องเข้าสู่ระบบใหม่" }
    var loginWebView: WKWebView { loginSource == .courseVille ? webView : classDeeDeeWebView }

    override init() {
        let makeWebView = { () -> WKWebView in
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            return WKWebView(frame: .zero, configuration: configuration)
        }
        webView = makeWebView()
        classDeeDeeWebView = makeWebView()
        super.init()
        if needsLogin { message = loginMessage }
        webView.navigationDelegate = self
        classDeeDeeWebView.navigationDelegate = self
        Task {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            await SessionCookieStore.restore(into: cookieStore)
            cookieSession = SessionCookieStore(store: cookieStore)
            webView.load(URLRequest(url: AssignmentSource.courseVille.home))
            if classDeeDeeEnabled {
                classDeeDeeWebView.load(URLRequest(url: AssignmentSource.classDeeDee.home))
            }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }
        refreshTimer?.tolerance = 60
    }

    deinit { refreshTimer?.invalidate() }

    func signIn(source: AssignmentSource = .courseVille) {
        loginSource = source
        if source == .classDeeDee {
            classDeeDeeEnabled = true
            AssignmentStore.enableClassDeeDee()
        }
        showLogin = true
        if AssignmentStore.needsLogin(for: source) || loginWebView.url == nil {
            loginWebView.load(URLRequest(url: source.home))
        }
    }

    func sync() async {
        guard !isSyncing else {
            syncRequested = true
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            if syncRequested {
                syncRequested = false
                Task { await sync() }
            }
        }
        var results: [String] = []
        var updated = false
        let sources: [AssignmentSource] = classDeeDeeEnabled ? [.courseVille, .classDeeDee] : [.courseVille]
        for source in sources {
            let view = source == .courseVille ? webView : classDeeDeeWebView
            guard view.url?.host == source.home.host, !view.isLoading else {
                results.append("\(source.name): รอเข้าสู่ระบบให้เสร็จ")
                continue
            }
            do {
                let old = assignments.filter { $0.origin == source }
                let known = old.filter { source == .courseVille || $0.shouldDisplay(at: .now) }.map {
                    ["url": $0.url.absoluteString, "title": $0.title,
                     "course": $0.course, "courseName": $0.courseName ?? "", "dueText": $0.dueLabel]
                }
                let knownData = try JSONSerialization.data(withJSONObject: known)
                let knownJSON = String(decoding: knownData, as: UTF8.self)
                var incoming: [Assignment]
                var failedCourses: [String] = []
                if source == .courseVille {
                    let result = try await SessionRecovery.fetch(
                        read: {
                            let data = try await self.readAssignments(source, knownJSON: knownJSON)
                            return try JSONDecoder().decode(FetchResult.self, from: data)
                        },
                        needsLogin: { $0.authRequired },
                        reload: { try await self.refreshMCVSession() })
                    if result.authRequired {
                        await requireLogin(source)
                        results.append("\(source.name): ต้องเข้าสู่ระบบใหม่")
                        continue
                    }
                    let previous = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
                    incoming = result.items.compactMap { Assignment(fetched: $0, previous: previous[$0.id]) }
                } else {
                    let data = try await readAssignments(source, knownJSON: knownJSON)
                    let result = try JSONDecoder().decode(ClassDeeDeeFetchResult.self, from: data)
                    if result.authRequired {
                        await requireLogin(source)
                        results.append("\(source.name): ต้องเข้าสู่ระบบใหม่")
                        continue
                    }
                    incoming = result.items.compactMap { Assignment(classDeeDee: $0) }
                    failedCourses = result.failedCourses
                    incoming += old.filter { failedCourses.contains($0.course) }
                }
                assignments = assignments.filter { $0.origin != source } + incoming
                AssignmentStore.save(assignments, source: source)
                updated = true
                let warning = failedCourses.isEmpty ? "" : " · บางวิชาซิงก์ไม่ได้ ใช้ข้อมูลเดิม"
                let hiddenReviewed = incoming.filter {
                    $0.hasReview && $0.isReviewPhase(at: .now) &&
                    $0.displayState(at: .now) == .submitted && !$0.shouldDisplay(at: .now)
                }.count
                let completed = hiddenReviewed > 0 ? " · รีวิวครบและพ้นกำหนด \(hiddenReviewed) งาน" : ""
                results.append("\(source.name): \(incoming.count) งาน\(completed)\(warning)")
                if source == .classDeeDee, let cookieSession,
                   await cookieSession.persist() != errSecSuccess {
                    results.append("เก็บเซสชันไม่ได้ · เปิดแอปใหม่อาจต้องล็อกอินอีกครั้ง")
                }
            } catch {
                results.append("\(source.name): ซิงก์ไม่สำเร็จ · ข้อมูลล่าสุดยังอยู่")
            }
        }
        lastSync = AssignmentStore.lastSync()
        loginSources = AssignmentStore.loginSources()
        message = results.joined(separator: "  |  ")
        if updated { await NotificationManager.reschedule(for: assignments) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func readAssignments(_ source: AssignmentSource, knownJSON: String) async throws -> Data {
        let view = source == .courseVille ? webView : classDeeDeeWebView
        let value = try await view.callAsyncJavaScript(
            source == .courseVille ? CourseVilleScript.fetchAssignments : ClassDeeDeeScript.fetchAssignments,
            arguments: ["previousItemsJSON": knownJSON], in: nil, contentWorld: .page)
        guard let json = value as? String, let data = json.data(using: .utf8) else {
            throw SyncError.invalidResponse
        }
        return data
    }

    private func refreshMCVSession() async throws -> Bool {
        // Leave a login form alone while the user is interacting with it.
        guard !(showLogin && loginSource == .courseVille) else { return false }
        message = "myCourseVille: กำลังตรวจเซสชันเดิมและซิงก์อีกครั้ง"
        return try await withCheckedThrowingContinuation { continuation in
            let request = URLRequest(url: AssignmentSource.courseVille.home,
                cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
            guard let navigation = webView.load(request) else {
                continuation.resume(throwing: SyncError.invalidResponse)
                return
            }
            let timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 25_000_000_000) }
                catch { return }
                self?.completeSessionRefresh(navigation, result: .failure(SyncError.sessionRefreshTimedOut))
            }
            sessionPageReload = SessionPageReload(navigation: navigation,
                continuation: continuation, timeout: timeout)
        }
    }

    @discardableResult
    private func completeSessionRefresh(_ navigation: WKNavigation?, result: Result<Bool, Error>) -> Bool {
        guard let pending = sessionPageReload, let navigation,
              pending.navigation === navigation else { return false }
        sessionPageReload = nil
        pending.timeout.cancel()
        pending.continuation.resume(with: result)
        return true
    }

    private func requireLogin(_ source: AssignmentSource) async {
        let shouldNotify = AssignmentStore.lastSync(for: source) != nil && !AssignmentStore.needsLogin(for: source)
        AssignmentStore.setNeedsLogin(true, source: source)
        loginSources = AssignmentStore.loginSources()
        WidgetCenter.shared.reloadAllTimelines()
        if shouldNotify { await NotificationManager.notifySessionExpired(source: source) }
    }

    func askForNotifications() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            message = allowed ? "เปิดการแจ้งเตือนส่งงานและรีวิวแล้ว" : "ยังไม่ได้อนุญาตการแจ้งเตือน"
            if allowed { await NotificationManager.reschedule(for: assignments) }
        } catch {
            message = "เปิดการแจ้งเตือนไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    func open(_ assignment: Assignment) { NSWorkspace.shared.open(assignment.displayURL(at: .now)) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // This refresh is already awaited by sync(); scheduling another sync
        // here would retry forever when the session really has expired.
        if completeSessionRefresh(navigation,
            result: .success(webView.url?.host == AssignmentSource.courseVille.home.host)) { return }
        let source: AssignmentSource = webView === classDeeDeeWebView ? .classDeeDee : .courseVille
        if webView.url?.host == source.home.host {
            Task { await sync() }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completeSessionRefresh(navigation, result: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completeSessionRefresh(navigation, result: .failure(error))
    }
}

private struct SessionPageReload {
    let navigation: WKNavigation
    let continuation: CheckedContinuation<Bool, Error>
    let timeout: Task<Void, Never>
}

private struct FetchResult: Decodable {
    let authRequired: Bool
    let items: [FetchedAssignment]
}

private struct ClassDeeDeeFetchResult: Decodable {
    let authRequired: Bool
    let items: [FetchedClassDeeDeeAssignment]
    let failedCourses: [String]
}

private enum SyncError: LocalizedError {
    case invalidResponse
    case sessionRefreshTimedOut
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "ข้อมูลตอบกลับจากเว็บไม่ถูกต้อง"
        case .sessionRefreshTimedOut: "โหลดหน้าเว็บเพื่อตรวจเซสชันไม่สำเร็จ"
        }
    }
}
