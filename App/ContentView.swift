import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("การบ้าน myCourseVille").font(.title2.bold())
                    Text(state.message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(state.needsLogin ? "ล็อกอินใหม่" : "เข้าสู่ระบบ CU") { state.signIn() }
                Button("ซิงก์") { Task { await state.sync() } }
                    .disabled(state.isSyncing)
                Button("เปิดแจ้งเตือน") { Task { await state.askForNotifications() } }
            }
            .padding()

            Divider()

            if state.needsLogin {
                Label("เซสชันหมดอายุ · งานด้านล่างเป็นข้อมูลที่ซิงก์ไว้ล่าสุด", systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }

            if state.assignments.isEmpty {
                ContentUnavailableView("ยังไม่มีรายการงาน", systemImage: "checklist",
                    description: Text("เข้าสู่ระบบ CU แล้วกดซิงก์เพื่อดึงรายการงาน"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(state.assignments) { assignment in
                    Button { state.open(assignment) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: assignment.state == .submitted ? "checkmark.circle.fill" :
                                    assignment.state == .pending ? "circle.fill" : "questionmark.circle.fill")
                                .foregroundStyle(color(for: assignment))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.title).font(.headline)
                                Text("\(assignment.courseName ?? assignment.course) · \(assignment.statusText)")
                                    .font(.subheadline).foregroundStyle(color(for: assignment))
                            }
                            Spacer()
                            if let due = assignment.dueAt {
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
                Text("สีเขียวอิงจากเวลาส่งจริงในหน้างาน")
            }
            .font(.caption2).foregroundStyle(.secondary).padding(10)
        }
        .frame(minWidth: 620, minHeight: 440)
        .sheet(isPresented: $state.showLogin) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("เข้าสู่ระบบ myCourseVille ด้วยบัญชี CU").font(.headline)
                        Text("สำหรับนิสิต ใช้รหัสนิสิต 10 หลักเป็นชื่อบัญชี ไม่ต้องใส่ @student.chula.ac.th")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("ปิดและซิงก์") {
                        state.showLogin = false
                        Task { await state.sync() }
                    }
                }
                .padding()
                LoginWebView(webView: state.webView)
            }
            .frame(minWidth: 900, minHeight: 650)
        }
    }

    private func color(for task: Assignment) -> Color {
        switch task.state {
        case .submitted: .green
        case .pending: .red
        case .unknown: .orange
        }
    }
}
