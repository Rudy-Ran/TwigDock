import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            Group {
                switch model.selectedSection ?? .overview {
                case .overview:
                    OverviewView(model: model)
                case .ports:
                    PortsView(model: model)
                case .worktrees:
                    WorktreesView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.isShowingNewWorktree = true
                    } label: {
                        Label("新建工作树", systemImage: "plus")
                    }
                    .disabled(model.repositories.isEmpty || model.isMutating)

                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(
                        !model.hasConfiguredScanRoot || model.isRefreshing || model.isMutating
                    )
                }
            }
        }
        .sheet(isPresented: $model.isShowingNewWorktree) {
            NewWorktreeSheet(model: model)
        }
        .sheet(
            isPresented: Binding(
                get: { !model.hasConfiguredScanRoot },
                set: { _ in }
            )
        ) {
            ScanRootOnboardingSheet(model: model)
                .interactiveDismissDisabled(true)
        }
        .sheet(item: $model.worktreeAwaitingRemoval) { worktree in
            RemoveWorktreeSheet(model: model, worktree: worktree)
        }
        .sheet(item: $model.repositoryBeingConfigured) { repository in
            RepositoryDisplaySettingsSheet(model: model, repository: repository)
        }
        .confirmationDialog(
            "停止这个进程？",
            isPresented: Binding(
                get: { model.portAwaitingStop != nil },
                set: { if !$0 { model.portAwaitingStop = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("停止进程", role: .destructive) {
                Task { await model.stopAwaitingPort() }
            }
            Button("取消", role: .cancel) {
                model.portAwaitingStop = nil
            }
        } message: {
            if let port = model.portAwaitingStop {
                Text(stopMessage(for: port))
            }
        }
        .alert(item: $model.message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.detail),
                dismissButton: .default(Text("知道了"))
            )
        }
        .task {
            model.startMonitoring()
        }
    }

    private func stopMessage(for port: PortRecord) -> String {
        "将向 \(port.processName)（PID \(String(port.pid))，端口 \(String(port.port))）发送 SIGTERM。"
    }
}
