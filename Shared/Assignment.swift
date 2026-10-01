import Foundation

enum SubmissionState: String, Codable {
    case pending
    case submitted
    case unknown
}

enum AssignmentSource: String, Codable, CaseIterable {
    case courseVille
    case classDeeDee

    var name: String { self == .courseVille ? "myCourseVille" : "ClassDeeDee" }
    var home: URL {
        URL(string: self == .courseVille
            ? "https://www.mycourseville.com/?q=courseville&type=course&role=all"
            : "https://classdeedee.cloud.cp.eng.chula.ac.th/")!
    }
}

struct AssignmentReminder {
    let dueAt: Date
    let availableAt: Date?
    let isReview: Bool
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
    var source: AssignmentSource?
    var reviewRequired: Bool?
    var reviewStartsAt: Date?
    var reviewDueAt: Date?
    var reviewCount: Int?
    var reviewMinimum: Int?
    var reviewURL: URL?

    var origin: AssignmentSource { source ?? .courseVille }
    var hasReview: Bool { reviewRequired == true }

    func isReviewPhase(at date: Date) -> Bool {
        hasReview && (dueAt.map { $0 <= date } ?? false)
    }

    var reviewState: SubmissionState {
        guard let count = reviewCount, let minimum = reviewMinimum else { return .unknown }
        return count >= minimum ? .submitted : .pending
    }

    func displayState(at date: Date) -> SubmissionState {
        isReviewPhase(at: date) && state == .submitted ? reviewState : state
    }

    func displayDueAt(at date: Date) -> Date? {
        isReviewPhase(at: date) ? reviewDueAt : dueAt
    }

    func displayURL(at date: Date) -> URL {
        isReviewPhase(at: date) && state == .submitted ? (reviewURL ?? url) : url
    }

    func displayTitle(at date: Date) -> String {
        isReviewPhase(at: date) ? "รีวิว: \(title)" : title
    }

    var isOverdue: Bool { state == .pending && (dueAt.map { $0 < .now } ?? false) }

    func shouldDisplay(at date: Date) -> Bool {
        // Keep a missed submission even if reviews are complete.
        if state == .pending { return true }
        return !(displayState(at: date) == .submitted &&
            (displayDueAt(at: date).map { $0 <= date } ?? false))
    }

    var statusText: String {
        statusText(at: .now)
    }

    func statusText(at date: Date) -> String {
        if isReviewPhase(at: date) {
            let progress = reviewCount.flatMap { count in reviewMinimum.map { "\(count)/\($0)" } } ?? "?"
            if state == .pending { return "ยังไม่ส่งงาน · รีวิวไม่ได้" }
            if state == .unknown { return "ตรวจสถานะส่งงานไม่ได้" }
            switch reviewState {
            case .submitted: return "รีวิวครบ \(progress)"
            case .unknown: return "ตรวจสถานะรีวิวไม่ได้"
            case .pending:
                if let start = reviewStartsAt, start > date { return "รอเปิดรีวิว · \(progress)" }
                let prefix = (reviewDueAt.map { $0 <= date } ?? false) ? "เลยกำหนด · " : ""
                return prefix + ((reviewCount ?? 0) == 0 ? "ยังไม่รีวิว · \(progress)" : "รีวิว \(progress) · ยังไม่ครบ")
            }
        }
        switch state {
        case .submitted: return "ส่งแล้ว"
        case .pending: return (dueAt.map { $0 <= date } ?? false) ? "เลยกำหนด · ยังไม่ส่ง" : "ยังไม่ส่ง"
        case .unknown: return "ตรวจสถานะไม่ได้"
        }
    }

    func detailText(at date: Date) -> String {
        let name = courseName ?? course
        return origin == .classDeeDee
            ? "ClassDeeDee · \(statusText(at: date)) · \(name)"
            : "\(name) · \(statusText(at: date))"
    }

    func reminders(at date: Date) -> [AssignmentReminder] {
        var result: [AssignmentReminder] = []
        if state == .pending, let dueAt, dueAt > date {
            result.append(AssignmentReminder(dueAt: dueAt, availableAt: nil, isReview: false))
        }
        if hasReview, state == .submitted, reviewState == .pending,
           let reviewDueAt, reviewDueAt > date {
            result.append(AssignmentReminder(dueAt: reviewDueAt,
                availableAt: [dueAt, reviewStartsAt].compactMap { $0 }.max(), isReview: true))
        }
        return result
    }

    static func visible(_ items: [Assignment], at date: Date) -> [Assignment] {
        items.filter { $0.shouldDisplay(at: date) }.sorted { left, right in
            let rank: (Assignment) -> Int = {
                switch $0.displayState(at: date) { case .pending: 0; case .unknown: 1; case .submitted: 2 }
            }
            if rank(left) != rank(right) { return rank(left) < rank(right) }
            let ld = left.displayDueAt(at: date), rd = right.displayDueAt(at: date)
            if ld == rd { return left.id < right.id }
            return rank(left) == 2 ? (ld ?? .distantPast) > (rd ?? .distantPast)
                : (ld ?? .distantFuture) < (rd ?? .distantFuture)
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

    static func parseUTC(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
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
        source = .courseVille
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

struct FetchedClassDeeDeeAssignment: Decodable {
    let id: String
    let title: String
    let course: String
    let courseName: String?
    let url: String
    let dueRaw: String?
    let submittedRaw: String?
    let state: SubmissionState
    let reviewRequired: Bool
    let reviewStartsRaw: String?
    let reviewDueRaw: String?
    let reviewCount: Int?
    let reviewMinimum: Int?
    let reviewURL: String
}

extension Assignment {
    init?(classDeeDee fetched: FetchedClassDeeDeeAssignment) {
        let host = "classdeedee.cloud.cp.eng.chula.ac.th"
        guard let link = URL(string: fetched.url), link.scheme == "https", link.host == host,
              let reviewLink = URL(string: fetched.reviewURL), reviewLink.scheme == "https",
              reviewLink.host == host else { return nil }
        id = fetched.id
        title = fetched.title
        course = fetched.course
        courseName = fetched.courseName
        url = link
        dueAt = CourseVilleDate.parseUTC(fetched.dueRaw)
        dueLabel = ""
        state = fetched.state
        submittedAt = CourseVilleDate.parseUTC(fetched.submittedRaw)
        checkedAt = .now
        source = .classDeeDee
        reviewRequired = fetched.reviewRequired
        reviewStartsAt = CourseVilleDate.parseUTC(fetched.reviewStartsRaw)
        reviewDueAt = CourseVilleDate.parseUTC(fetched.reviewDueRaw)
        reviewCount = fetched.reviewCount
        reviewMinimum = fetched.reviewMinimum
        reviewURL = reviewLink
    }
}
