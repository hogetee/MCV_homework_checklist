import Foundation
import UserNotifications

enum NotificationManager {
    static func notifySessionExpired(source: AssignmentSource = .courseVille) async {
        let content = UNMutableNotificationContent()
        content.title = "ต้องเข้าสู่ระบบ \(source.name) ใหม่"
        content.body = "เปิด MCVNot เพื่อล็อกอินและอัปเดตการบ้านในวิดเจ็ต"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "mcvnot.session-expired.\(source.rawValue)",
                                            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func reschedule(for assignments: [Assignment]) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            existing.map(\.identifier).filter { $0.hasPrefix("mcvnot.") })

        let now = Date()
        for task in assignments {
          for reminder in task.reminders(at: now) {
            for hours in [24, 6, 1] {
                let fire = reminder.dueAt.addingTimeInterval(TimeInterval(-hours * 3600))
                guard fire > now, reminder.availableAt.map({ fire >= $0 }) ?? true else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(reminder.isReview ? "รีวิวใกล้หมดเวลา" : "การบ้านใกล้ส่ง"): \(task.title)"
                content.body = "\(task.courseName ?? task.course) · เหลือ \(hours) ชั่วโมง · \(reminder.isReview ? "ยังรีวิวไม่ครบ" : "ยังไม่ส่งงาน")"
                content.sound = .default
                let parts = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let identifier = "mcvnot.\(task.id.hashValue).\(reminder.isReview ? "review" : "submit").\(hours)"
                try? await center.add(UNNotificationRequest(
                    identifier: identifier, content: content, trigger: trigger))
            }
          }
        }
    }
}
