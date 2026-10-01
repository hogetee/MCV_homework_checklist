import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var currentDate = Date()

    private var visibleAssignments: [Assignment] {
        Assignment.visible(state.assignments, at: currentDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("การบ้านและรีวิว").font(.title2.bold())
                    Text(state.message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("myCourseVille") { state.signIn() }
                Button(state.classDeeDeeEnabled ? "ClassDeeDee" : "เชื่อม ClassDeeDee") {
                    state.signIn(source: .classDeeDee)
                }
                Button("ซิงก์") { Task { await state.sync() } }
                    .disabled(state.isSyncing)
                Button("เปิดแจ้งเตือน") { Task { await state.askForNotifications() } }
            }
            .padding()

            Divider()

            if state.needsLogin {
                Label(state.loginMessage + " · แสดงข้อมูลล่าสุดที่เก็บไว้", systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }

            if visibleAssignments.isEmpty {
                ContentUnavailableView("ยังไม่มีรายการงาน", systemImage: "checklist",
                    description: Text(state.assignments.isEmpty
                        ? "เลือกเว็บเพื่อเข้าสู่ระบบ แล้วกดซิงก์เพื่อดึงรายการงาน"
                        : "งานที่ส่งและรีวิวครบแล้วจะถูกซ่อนเมื่อพ้นกำหนด"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleAssignments) { assignment in
                    Button { state.open(assignment) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: assignment.displayState(at: currentDate) == .submitted ? "checkmark.circle.fill" :
                                    assignment.displayState(at: currentDate) == .pending ? "circle.fill" : "questionmark.circle.fill")
                                .foregroundStyle(color(for: assignment))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.displayTitle(at: currentDate)).font(.headline)
                                Text(assignment.detailText(at: currentDate))
                                    .font(.subheadline).foregroundStyle(color(for: assignment))
                            }
                            Spacer()
                            if let due = assignment.displayDueAt(at: currentDate) {
                                Text(due, format: .dateTime.day().month().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if !assignment.dueLabel.isEmpty {
                                Text(assignment.dueLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                if let lastSync = state.lastSync {
                    Text("อัปเดตล่าสุด \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("ยังไม่เคยซิงก์")
                }
                Spacer()
                Text("สีเขียว: ส่งแล้วหรือรีวิวครบตามข้อมูลจากเว็บ")
            }
            .font(.caption2).foregroundStyle(.secondary).padding(10)
        }
        .frame(minWidth: 780, minHeight: 440)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { currentDate = $0 }
        .sheet(isPresented: $state.showLogin) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("เข้าสู่ระบบ \(state.loginSource.name)").font(.headline)
                        Text(state.loginSource == .courseVille
                            ? "สำหรับนิสิต ใช้รหัสนิสิต 10 หลักเป็นชื่อบัญชี ไม่ต้องใส่ @student.chula.ac.th"
                            : "เลือก Connect with Chula SSO แล้วเข้าสู่ระบบด้วยบัญชี CU ของคุณ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("ปิดและซิงก์") {
                        state.showLogin = false
                        Task { await state.sync() }
                    }
                }
                .padding()
                LoginWebView(webView: state.loginWebView).id(state.loginSource)
            }
            .frame(minWidth: 900, minHeight: 650)
        }
    }

    private func color(for task: Assignment) -> Color {
        switch task.displayState(at: currentDate) {
        case .submitted: .green
        case .pending: .red
        case .unknown: .orange
        }
    }
}
