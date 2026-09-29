import SwiftUI
import WidgetKit

struct MCVEntry: TimelineEntry {
    let date: Date
    let assignments: [Assignment]
    let lastSync: Date?
    let needsLogin: Bool
}

struct MCVProvider: TimelineProvider {
    func placeholder(in context: Context) -> MCVEntry {
        MCVEntry(date: .now, assignments: [], lastSync: nil, needsLogin: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MCVEntry) -> Void) {
        completion(MCVEntry(date: .now, assignments: AssignmentStore.load(),
                            lastSync: AssignmentStore.lastSync(),
                            needsLogin: AssignmentStore.needsLogin()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MCVEntry>) -> Void) {
        let tasks = AssignmentStore.load()
        let lastSync = AssignmentStore.lastSync()
        let needsLogin = AssignmentStore.needsLogin()
        let now = Date()
        let nextDates = tasks.compactMap(\.dueAt).flatMap { due in
            [due.addingTimeInterval(-24 * 3600), due.addingTimeInterval(-6 * 3600),
             due.addingTimeInterval(-3600), due]
        }.filter { $0 > now && $0 < now.addingTimeInterval(24 * 3600) }
        let dates = Array(Set([now] + nextDates)).sorted()
        let entries = dates.map { MCVEntry(date: $0, assignments: tasks,
                                           lastSync: lastSync, needsLogin: needsLogin) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct MCVWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MCVEntry

    private var visibleAssignments: [Assignment] {
        entry.assignments.filter { $0.shouldDisplay(at: entry.date) }
    }

    var body: some View {
        Group {
            if family == .systemLarge {
                ViewThatFits(in: .vertical) {
                    assignmentList(limit: 7)
                    assignmentList(limit: 6)
                    assignmentList(limit: 5)
                    assignmentList(limit: 4)
                    assignmentList(limit: 3)
                    assignmentList(limit: 2)
                    assignmentList(limit: 1)
                    assignmentList(limit: 0)
                }
            } else {
                ViewThatFits(in: .vertical) {
                    assignmentList(limit: 3)
                    assignmentList(limit: 2)
                    assignmentList(limit: 1)
                    assignmentList(limit: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
    }

    private func assignmentList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("การบ้าน MCV").font(.headline)
                Spacer(minLength: 0)
                Text("\(entry.assignments.filter { $0.state == .pending }.count) ค้าง")
                    .font(.caption.bold())
            }

            if entry.needsLogin {
                Text("เซสชันหมดอายุ · เปิดแอปเพื่อล็อกอินใหม่")
                    .font(.caption2).foregroundStyle(.orange)
            } else if let lastSync = entry.lastSync,
                      entry.date.timeIntervalSince(lastSync) > 60 * 60 {
                Text("ข้อมูลเก่า · เปิดแอปเพื่อซิงก์")
                    .font(.caption2).foregroundStyle(.orange)
            }

            if entry.assignments.isEmpty {
                Text("เปิดแอปเพื่อล็อกอินและซิงก์งาน")
                    .font(.caption).foregroundStyle(.secondary)
            } else if visibleAssignments.isEmpty {
                Text("ไม่มีงานค้าง")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(visibleAssignments.prefix(limit))) { task in
                    Link(destination: task.url) {
                        HStack(spacing: 7) {
                            Image(systemName: task.state == .submitted ? "checkmark.circle.fill" :
                                    task.state == .pending ? "circle.fill" : "questionmark.circle.fill")
                                .foregroundStyle(color(for: task))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.title).lineLimit(1).font(.caption.bold())
                                Text("\(task.courseName ?? task.course) · \(task.statusText)")
                                    .lineLimit(1).font(.caption2)
                                    .foregroundStyle(color(for: task))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func color(for task: Assignment) -> Color {
        switch task.state {
        case .submitted: .green
        case .pending: .red
        case .unknown: .orange
        }
    }
}

struct MCVWidget: Widget {
    let kind = "MCVHomeworkWidgetV2"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MCVProvider()) { entry in
            MCVWidgetView(entry: entry)
        }
        .configurationDisplayName("การบ้าน myCourseVille (ใหม่)")
        .description("งานที่ยังไม่ส่งและงานที่ส่งแล้ว พร้อมกำหนดส่ง")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct MCVWidgetBundle: WidgetBundle {
    var body: some Widget { MCVWidget() }
}
