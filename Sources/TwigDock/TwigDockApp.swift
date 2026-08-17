import SwiftUI

@main
struct TwigDockApp: App {
    @StateObject private var model = AppModel()
    @State private var isMenuBarExtraInserted = true

    var body: some Scene {
        WindowGroup("TwigDock", id: "main") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建工作树…") {
                    model.isShowingNewWorktree = true
                }
                .keyboardShortcut("n")
                .disabled(model.repositories.isEmpty)
            }
            CommandMenu("数据") {
                Button("刷新全部") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r")
                .disabled(!model.hasConfiguredScanRoot)
            }
        }

        MenuBarExtra(
            "TwigDock",
            systemImage: "point.3.connected.trianglepath.dotted",
            isInserted: $isMenuBarExtraInserted
        ) {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
