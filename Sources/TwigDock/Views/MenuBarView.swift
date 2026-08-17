import AppKit
import SwiftUI

private enum MenuBarPage: String, CaseIterable, Identifiable {
    case ports
    case worktrees

    var id: String { rawValue }
}

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedPage: MenuBarPage = .ports

    private var content: MenuBarContentSnapshot {
        model.menuBarContent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if model.hasConfiguredScanRoot {
                configuredContent
            } else {
                configurationPrompt
            }

            Divider()
            footer
        }
        .frame(width: 420)
        .frame(height: model.hasConfiguredScanRoot ? 650 : 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            model.startMonitoring()
        }
        .onAppear {
            if content.projectPorts.isEmpty && !content.additionalWorktrees.isEmpty {
                selectedPage = .worktrees
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TwigDockMark(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("TwigDock")
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .help("正在刷新")
            } else {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!model.hasConfiguredScanRoot || model.isMutating)
                .help("刷新全部")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var summaryText: String {
        guard model.hasConfiguredScanRoot else { return "尚未选择代码目录" }
        return "\(content.projectPorts.count) 个项目端口 · \(content.additionalWorktrees.count) 个工作树"
    }

    private var configuredContent: some View {
        VStack(spacing: 0) {
            Picker("速览内容", selection: $selectedPage) {
                Text("项目端口  \(content.projectPorts.count)")
                    .tag(MenuBarPage.ports)
                Text("工作树  \(content.additionalWorktrees.count)")
                    .tag(MenuBarPage.worktrees)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            switch selectedPage {
            case .ports:
                portPage
            case .worktrees:
                worktreePage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var portPage: some View {
        VStack(spacing: 0) {
            pageHeader(
                title: "项目端口",
                subtitle: "只显示从已扫描项目启动的服务",
                actionTitle: "在主窗口查看",
                action: showProjectPorts
            )
            Divider()

            if content.projectPorts.isEmpty {
                menuEmptyState(
                    systemImage: "network",
                    title: "暂无项目端口",
                    detail: "从扫描目录中的项目启动服务后，会自动显示在这里。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(content.projectPorts) { port in
                            MenuBarPortRow(model: model, port: port) {
                                model.portSearch = ""
                                model.portScope = .projects
                                model.showPort(port)
                                presentMainWindow()
                            }
                        }
                    }
                    .padding(5)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var worktreePage: some View {
        VStack(spacing: 0) {
            pageHeader(
                title: "附加工作树",
                subtitle: "主工作树不会计入此处",
                actionTitle: "在主窗口查看",
                action: showWorktrees
            )
            Divider()

            if content.additionalWorktrees.isEmpty {
                menuEmptyState(
                    systemImage: "arrow.triangle.branch",
                    title: "暂无附加工作树",
                    detail: "新建 Worktree 后，会自动显示在这里。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(content.additionalWorktrees) { worktree in
                            MenuBarWorktreeRow(model: model, worktree: worktree) {
                                model.worktreeSearch = ""
                                model.worktreeScope = .all
                                model.showWorktree(worktree)
                                presentMainWindow()
                            }
                        }
                    }
                    .padding(5)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pageHeader(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(actionTitle, action: action)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func menuEmptyState(
        systemImage: String,
        title: String,
        detail: String
    ) -> some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var configurationPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(.secondary)
            Text("先选择代码目录")
                .font(.headline)
            Text("完成首次配置后，这里才会显示项目端口和附加工作树。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
            Button("打开 TwigDock") {
                presentMainWindow()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack {
            Button {
                presentMainWindow()
            } label: {
                Label("打开 TwigDock", systemImage: "macwindow")
            }
            .buttonStyle(.plain)
            .font(.caption)

            Spacer()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private func showProjectPorts() {
        model.portSearch = ""
        model.portScope = .projects
        model.selectedSection = .ports
        presentMainWindow()
    }

    private func showWorktrees() {
        model.worktreeSearch = ""
        model.worktreeScope = .all
        model.selectedSection = .worktrees
        presentMainWindow()
    }

    private func presentMainWindow() {
        if let window = NSApplication.shared.windows.first(where: {
            $0.title == "TwigDock" && $0.canBecomeMain
        }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct MenuBarPortRow: View {
    @ObservedObject var model: AppModel
    let port: PortRecord
    let action: () -> Void
    @State private var isHovering = false

    private var linkedWorktree: WorktreeRecord? {
        guard let worktreeID = port.worktreeID else { return nil }
        return model.worktrees.first { $0.id == worktreeID }
    }

    private var contextText: String {
        guard let linkedWorktree else { return port.processName }
        let branch = linkedWorktree.isMain
            ? "主目录 · \(linkedWorktree.branch)"
            : linkedWorktree.branch
        return "\(branch) · \(port.processName)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(":" + String(port.port))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 58, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName(for: port))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(contextText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                (isHovering ? Color.accentColor.opacity(0.09) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("打开 \(model.displayName(for: port)) 端口 \(port.port)")
    }
}

private struct MenuBarWorktreeRow: View {
    @ObservedObject var model: AppModel
    let worktree: WorktreeRecord
    let action: () -> Void
    @State private var isHovering = false

    private var statusColor: Color {
        switch worktree.status {
        case .clean: .green
        case .dirty: .orange
        case .stale: .secondary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worktree.branch)
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(model.displayName(for: worktree))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(worktree.status.title)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                (isHovering ? Color.accentColor.opacity(0.09) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("打开 \(model.displayName(for: worktree)) 工作树 \(worktree.branch)")
    }
}
