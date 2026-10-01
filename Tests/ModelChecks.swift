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
        legacyRecord.removeValue(forKey: "source")
        let legacyData = try! JSONSerialization.data(withJSONObject: legacyRecord)
        let migrated = try! JSONDecoder().decode(Assignment.self, from: legacyData)
        precondition(migrated.courseName == nil)
        precondition(migrated.origin == .courseVille)

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

        let cdd = FetchedClassDeeDeeAssignment(
            id: "classdeedee:course:one", title: "Example peer assignment", course: "course",
            courseName: "Example Course", url: "https://classdeedee.cloud.cp.eng.chula.ac.th/courses/course/assignments/submission/one",
            dueRaw: "2026-10-01T16:59:00.000Z", submittedRaw: "2026-09-30T01:00:00.000Z", state: .submitted,
            reviewRequired: true, reviewStartsRaw: "2026-10-01T17:00:00.000Z", reviewDueRaw: "2026-10-04T16:59:00.000Z",
            reviewCount: 0, reviewMinimum: 3,
            reviewURL: "https://classdeedee.cloud.cp.eng.chula.ac.th/courses/course/assignments/panel/one")
        var review = Assignment(classDeeDee: cdd)!
        let submissionDeadline = review.dueAt!, reviewDeadline = review.reviewDueAt!
        let before = submissionDeadline.addingTimeInterval(-1)
        let after = submissionDeadline.addingTimeInterval(120)
        precondition(review.displayState(at: before) == .submitted)
        precondition(review.statusText(at: before) == "ส่งแล้ว")
        precondition(review.shouldDisplay(at: after))
        precondition(review.displayState(at: after) == .pending)
        precondition(review.statusText(at: after).contains("ยังไม่รีวิว"))
        precondition(review.displayDueAt(at: after) == reviewDeadline)
        precondition(review.displayURL(at: after) == review.reviewURL)
        precondition(review.reminders(at: before).count == 1)
        precondition(review.reminders(at: before)[0].isReview)
        precondition(review.reminders(at: before)[0].availableAt == review.reviewStartsAt)
        review.reviewCount = 2
        precondition(review.statusText(at: after).contains("2/3"))
        precondition(review.displayState(at: after) == .pending)
        precondition(review.shouldDisplay(at: reviewDeadline.addingTimeInterval(1)))
        review.reviewCount = 3
        precondition(review.displayState(at: after) == .submitted)
        precondition(review.reminders(at: after).isEmpty)
        precondition(!review.shouldDisplay(at: reviewDeadline))
        review.reviewCount = nil
        precondition(review.displayState(at: after) == .unknown)
        precondition(review.shouldDisplay(at: reviewDeadline))
        review.state = .pending
        precondition(review.displayURL(at: after) == review.url)
        precondition(review.shouldDisplay(at: reviewDeadline))
        precondition(review.displayState(at: after) == .pending)
        precondition(review.reminders(at: after).isEmpty)
        precondition(CourseVilleDate.parseUTC("2026-10-01T16:59:00.000Z") == CourseVilleDate.parse("1-Oct-2026 23:59"))
        print("Model checks passed")
    }
}
