import SwiftUI

@main
struct MCVNotApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup(id: "main") { ContentView(state: state) }
        MenuBarExtra("การบ้านและรีวิว", systemImage: "checklist") {
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
                Text("การบ้านและรีวิว").font(.headline)
                Text(state.message).font(.caption).foregroundStyle(.secondary)
                ForEach(Assignment.visible(state.assignments, at: .now).prefix(5)) { task in
                    Button("\(task.displayState(at: .now) == .submitted ? "🟢" : task.displayState(at: .now) == .pending ? "🔴" : "🟠") \(task.displayTitle(at: .now))") {
                        state.open(task)
                    }
                }
                Divider()
                Button("ซิงก์ตอนนี้") { Task { await state.sync() } }
                Button("เข้าสู่ระบบ myCourseVille") {
                    openWindow(id: "main")
                    state.signIn()
                }
                Button("เข้าสู่ระบบ ClassDeeDee") {
                    openWindow(id: "main")
                    state.signIn(source: .classDeeDee)
                }
            }
            .padding(12)
            .frame(width: 300)
    }
}
