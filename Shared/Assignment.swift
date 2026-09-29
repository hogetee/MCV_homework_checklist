import Foundation

enum SubmissionState: String, Codable {
    case pending
    case submitted
    case unknown
}

struct Assignment: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var course: String
    var courseName: String?
    var url: URL
    var dueAt: Date?
    var dueLabel: String
    var state: SubmissionState
    var submittedAt: Date?
    var checkedAt: Date

    var isOverdue: Bool { state == .pending && (dueAt.map { $0 < .now } ?? false) }

    func shouldDisplay(at date: Date) -> Bool {
        !(state == .submitted && (dueAt.map { $0 <= date } ?? false))
    }

    var statusText: String {
        switch state {
        case .submitted: return "ส่งแล้ว"
        case .pending: return isOverdue ? "เลยกำหนด · ยังไม่ส่ง" : "ยังไม่ส่ง"
        case .unknown: return "ตรวจสถานะไม่ได้"
        }
    }
}

struct FetchedAssignment: Decodable {
    let id: String
    let title: String
    let course: String
    let courseName: String?
    let url: String
    let dueText: String
    let dueRaw: String?
    let submittedRaw: String?
    let detailLoaded: Bool
}

enum CourseVilleDate {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
        for pattern in ["d-MMM-yyyy HH:mm:ss", "d-MM-yyyy HH:mm:ss",
                        "d MMM yyyy HH:mm:ss", "d MMMM yyyy HH:mm:ss",
                        "d-MMM-yyyy HH:mm", "d-MM-yyyy HH:mm",
                        "d MMM yyyy HH:mm", "d MMMM yyyy HH:mm"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

extension Assignment {
    init?(fetched: FetchedAssignment, previous: Assignment?) {
        guard let link = URL(string: fetched.url), link.host == "www.mycourseville.com" else { return nil }
        id = fetched.id
        title = fetched.title.isEmpty ? (previous?.title ?? "งานที่ไม่มีชื่อ") : fetched.title
        course = fetched.course.isEmpty ? (previous?.course ?? "myCourseVille") : fetched.course
        courseName = fetched.courseName?.isEmpty == false ? fetched.courseName : previous?.courseName
        url = link
        dueAt = CourseVilleDate.parse(fetched.dueRaw) ?? previous?.dueAt
        dueLabel = fetched.dueText.isEmpty ? (previous?.dueLabel ?? "") : fetched.dueText
        if fetched.detailLoaded {
            submittedAt = CourseVilleDate.parse(fetched.submittedRaw)
            if fetched.submittedRaw != nil {
                state = submittedAt == nil ? .unknown : .submitted
            } else {
                state = .pending
            }
            checkedAt = .now
        } else {
            submittedAt = previous?.submittedAt
            state = previous?.state ?? .unknown
            checkedAt = previous?.checkedAt ?? .distantPast
        }
    }
}
