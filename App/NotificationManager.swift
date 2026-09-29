import Foundation
import UserNotifications

enum NotificationManager {
    static func notifySessionExpired() async {
        let content = UNMutableNotificationContent()
        content.title = "ต้องเข้าสู่ระบบ myCourseVille ใหม่"
        content.body = "เปิด MCVNot เพื่อล็อกอินและอัปเดตการบ้านในวิดเจ็ต"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "mcvnot.session-expired",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func reschedule(for assignments: [Assignment]) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            existing.map(\.identifier).filter { $0.hasPrefix("mcvnot.") })

        for task in assignments where task.state == .pending {
            guard let due = task.dueAt, due > .now else { continue }
            for hours in [24, 6, 1] {
                let fire = due.addingTimeInterval(TimeInterval(-hours * 3600))
                guard fire > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "การบ้านใกล้ส่ง: \(task.title)"
                content.body = "\(task.courseName ?? task.course) · เหลือ \(hours) ชั่วโมง และยังไม่พบการส่งงาน"
                content.sound = .default
                let parts = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let identifier = "mcvnot.\(task.id.hashValue).\(hours)"
                try? await center.add(UNNotificationRequest(
                    identifier: identifier, content: content, trigger: trigger))
            }
        }
    }
}
