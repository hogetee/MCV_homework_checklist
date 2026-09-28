import SwiftUI

@main
struct MCVNotApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup(id: "main") { ContentView(state: state) }
        MenuBarExtra("การบ้าน MCV", systemImage: "checklist") {
            MenuPanel(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuPanel: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var state: AppState

    var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("การบ้าน myCourseVille").font(.headline)
                Text(state.message).font(.caption).foregroundStyle(.secondary)
                ForEach(state.assignments.prefix(5)) { task in
                    Button("\(task.state == .submitted ? "🟢" : task.state == .pending ? "🔴" : "🟠") \(task.title)") {
                        state.open(task)
                    }
                }
                Divider()
                Button("ซิงก์ตอนนี้") { Task { await state.sync() } }
                Button("เข้าสู่ระบบ CU") {
                    openWindow(id: "main")
                    state.signIn()
                }
            }
            .padding(12)
            .frame(width: 300)
    }
}
