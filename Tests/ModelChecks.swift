import Foundation

@main
struct ModelChecks {
    static func main() {
        let url = "https://www.mycourseville.com/?q=courseville/worksheet/1/1"
        let submitted = FetchedAssignment(
            id: url, title: "Example assignment", course: "1234567",
            courseName: "Example Course", url: url,
            dueText: "dues in 23 hours", dueRaw: "28-Sep-2026 23:59",
            submittedRaw: "28-09-2026 00:10:18", detailLoaded: true)
        let completed = Assignment(fetched: submitted, previous: nil)!
        precondition(completed.state == .submitted)
        precondition(completed.dueAt != nil)
        precondition(completed.submittedAt != nil)
        let due = completed.dueAt!
        precondition(completed.shouldDisplay(at: due.addingTimeInterval(-1)))
        precondition(!completed.shouldDisplay(at: due))

        let stored = try! JSONEncoder().encode(completed)
        var legacyRecord = try! JSONSerialization.jsonObject(with: stored) as! [String: Any]
        legacyRecord.removeValue(forKey: "courseName")
        let legacyData = try! JSONSerialization.data(withJSONObject: legacyRecord)
        let migrated = try! JSONDecoder().decode(Assignment.self, from: legacyData)
        precondition(migrated.courseName == nil)

        let pending = FetchedAssignment(
            id: url, title: "Example assignment", course: "1234567",
            courseName: "Example Course", url: url,
            dueText: "", dueRaw: "28-Sep-2026 23:59",
            submittedRaw: nil, detailLoaded: true)
        let notSubmitted = Assignment(fetched: pending, previous: nil)!
        precondition(notSubmitted.state == .pending)
        precondition(notSubmitted.shouldDisplay(at: due.addingTimeInterval(1)))

        let unavailable = FetchedAssignment(
            id: url, title: "", course: "", courseName: nil, url: url, dueText: "",
            dueRaw: nil, submittedRaw: nil, detailLoaded: false)
        let preserved = Assignment(fetched: unavailable, previous: completed)!
        precondition(preserved.state == .submitted)
        precondition(preserved.dueAt == completed.dueAt)
        var noDueDate = completed
        noDueDate.dueAt = nil
        precondition(noDueDate.shouldDisplay(at: due.addingTimeInterval(1)))

        let fromCourseList = FetchedAssignment(
            id: url, title: "Upcoming assignment", course: "1234567",
            courseName: "Example Course", url: url,
            dueText: "Due on 05 October 2026 at 23:59",
            dueRaw: "05 October 2026 23:59",
            submittedRaw: nil, detailLoaded: true)
        let upcoming = Assignment(fetched: fromCourseList, previous: nil)!
        precondition(upcoming.state == .pending)
        precondition(upcoming.dueAt != nil)
        precondition(CourseVilleDate.parse("28 Sep 2026 00:10:18") != nil)
        print("Model checks passed")
    }
}
