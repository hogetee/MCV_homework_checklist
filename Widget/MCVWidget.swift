import SwiftUI
import WidgetKit

struct MCVEntry: TimelineEntry {
    let date: Date
    let assignments: [Assignment]
    let lastSync: Date?
    let loginSources: [AssignmentSource]
}

struct MCVProvider: TimelineProvider {
    func placeholder(in context: Context) -> MCVEntry {
        MCVEntry(date: .now, assignments: [], lastSync: nil, loginSources: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MCVEntry) -> Void) {
        completion(MCVEntry(date: .now, assignments: AssignmentStore.load(),
                            lastSync: AssignmentStore.lastSync(),
                            loginSources: AssignmentStore.loginSources()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MCVEntry>) -> Void) {
        let tasks = AssignmentStore.load()
        let lastSync = AssignmentStore.lastSync()
        let loginSources = AssignmentStore.loginSources()
        let now = Date()
        let deadlines = tasks.flatMap { [$0.dueAt, $0.reviewDueAt].compactMap { $0 } }
        let nextDates = (deadlines.flatMap { due in
            [due.addingTimeInterval(-24 * 3600), due.addingTimeInterval(-6 * 3600),
             due.addingTimeInterval(-3600), due]
        } + tasks.compactMap(\.reviewStartsAt)).filter { $0 > now && $0 < now.addingTimeInterval(24 * 3600) }
        let dates = Array(Set([now] + nextDates)).sorted()
        let entries = dates.map { MCVEntry(date: $0, assignments: tasks,
                                           lastSync: lastSync, loginSources: loginSources) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct MCVWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MCVEntry

    private var visibleAssignments: [Assignment] {
        Assignment.visible(entry.assignments, at: entry.date)
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
                Text("การบ้านและรีวิว").font(.headline)
                Spacer(minLength: 0)
                Text("\(visibleAssignments.filter { $0.displayState(at: entry.date) == .pending }.count) ค้าง")
                    .font(.caption.bold())
            }

            if !entry.loginSources.isEmpty {
                Text(entry.loginSources.map(\.name).joined(separator: ", ") + " · ต้องล็อกอินใหม่")
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
                    Link(destination: task.displayURL(at: entry.date)) {
                        HStack(spacing: 7) {
                            Image(systemName: task.displayState(at: entry.date) == .submitted ? "checkmark.circle.fill" :
                                    task.displayState(at: entry.date) == .pending ? "circle.fill" : "questionmark.circle.fill")
                                .foregroundStyle(color(for: task))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.displayTitle(at: entry.date)).lineLimit(1).font(.caption.bold())
                                Text(task.detailText(at: entry.date))
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
        switch task.displayState(at: entry.date) {
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
        .configurationDisplayName("การบ้าน MCV + ClassDeeDee")
        .description("สถานะส่งงานและรีวิว พร้อมกำหนดส่งจากทั้งสองเว็บ")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct MCVWidgetBundle: WidgetBundle {
    var body: some Widget { MCVWidget() }
}
