import AppKit
import Combine
import Foundation
import UserNotifications
import WebKit
import WidgetKit

@MainActor
final class AppState: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var assignments: [Assignment] = AssignmentStore.load()
    @Published private(set) var lastSync: Date? = AssignmentStore.lastSync()
    @Published private(set) var isSyncing = false
    @Published private(set) var isSignedIn = false
    @Published private(set) var needsLogin = AssignmentStore.needsLogin()
    @Published var message = "ลงชื่อเข้าใช้ด้วย CU Account เพื่อซิงก์การบ้าน"
    @Published var showLogin = false

    let webView: WKWebView
    private var refreshTimer: Timer?
    private let home = URL(string: "https://www.mycourseville.com/?q=courseville&type=course&role=all")!

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        if needsLogin { message = "เซสชันหมดอายุ · กดล็อกอินใหม่เพื่ออัปเดตงาน" }
        webView.navigationDelegate = self
        webView.load(URLRequest(url: home))
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }
    }

    deinit { refreshTimer?.invalidate() }

    func signIn() {
        showLogin = true
        if needsLogin || webView.url == nil { webView.load(URLRequest(url: home)) }
    }

    func sync() async {
        guard !isSyncing else { return }
        guard webView.url?.host == "www.mycourseville.com" else {
            message = "กรุณาเข้าสู่ระบบ CU ให้เสร็จก่อนซิงก์"
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let known = assignments.map {
                ["url": $0.url.absoluteString, "title": $0.title,
                 "course": $0.course, "courseName": $0.courseName ?? "",
                 "dueText": $0.dueLabel]
            }
            let knownData = try JSONSerialization.data(withJSONObject: known)
            let knownJSON = String(decoding: knownData, as: UTF8.self)
            let value = try await webView.callAsyncJavaScript(
                CourseVilleScript.fetchAssignments,
                arguments: ["previousItemsJSON": knownJSON],
                in: nil,
                contentWorld: .page
            )
            guard let json = value as? String, let data = json.data(using: .utf8) else {
                throw SyncError.invalidResponse
            }
            let result = try JSONDecoder().decode(FetchResult.self, from: data)
            if result.authRequired {
                await requireLogin()
                return
            }
            let fetched = result.items
            let previous = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
            assignments = fetched.compactMap { Assignment(fetched: $0, previous: previous[$0.id]) }
                .sorted { left, right in
                    let leftPriority = left.state == .pending ? 0 : (left.state == .unknown ? 1 : 2)
                    let rightPriority = right.state == .pending ? 0 : (right.state == .unknown ? 1 : 2)
                    if leftPriority != rightPriority { return leftPriority < rightPriority }
                    if left.state == .submitted {
                        return (left.dueAt ?? .distantPast) > (right.dueAt ?? .distantPast)
                    }
                    return (left.dueAt ?? .distantFuture) < (right.dueAt ?? .distantFuture)
                }
            AssignmentStore.save(assignments)
            lastSync = .now
            isSignedIn = true
            needsLogin = false
            message = assignments.isEmpty ? "ไม่พบงานในรายวิชาปัจจุบัน" : "ซิงก์แล้ว \(assignments.count) งาน"
            await NotificationManager.reschedule(for: assignments)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            message = "ซิงก์ไม่สำเร็จ: \(error.localizedDescription) · ข้อมูลล่าสุดยังอยู่"
        }
    }

    private func requireLogin() async {
        guard lastSync != nil else {
            message = "กรุณาเข้าสู่ระบบ CU ในแอปก่อนซิงก์"
            return
        }
        let shouldNotify = !needsLogin
        needsLogin = true
        isSignedIn = false
        AssignmentStore.setNeedsLogin(true)
        message = "เซสชันหมดอายุ · กดล็อกอินใหม่เพื่ออัปเดตงาน"
        WidgetCenter.shared.reloadAllTimelines()
        if shouldNotify { await NotificationManager.notifySessionExpired() }
    }

    func askForNotifications() async {
        do {
            let allowed = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            message = allowed ? "เปิดการแจ้งเตือนแล้ว" : "ยังไม่ได้อนุญาตการแจ้งเตือน"
            if allowed { await NotificationManager.reschedule(for: assignments) }
        } catch {
            message = "เปิดการแจ้งเตือนไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    func open(_ assignment: Assignment) { NSWorkspace.shared.open(assignment.url) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.host == "www.mycourseville.com", webView.url?.path == "/" {
            Task { await sync() }
        }
    }
}

private struct FetchResult: Decodable {
    let authRequired: Bool
    let items: [FetchedAssignment]
}

private enum SyncError: LocalizedError {
    case invalidResponse
    var errorDescription: String? { "ข้อมูลตอบกลับจาก myCourseVille ไม่ถูกต้อง" }
}
