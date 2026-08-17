import SwiftUI

struct WorktreesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: "工作树管理",
                        subtitle: "只管理额外创建的 Worktree；仓库主目录不会计入这里。"
                    )

                    HStack(spacing: 10) {
                        TextField("搜索仓库、分支或路径", text: $model.worktreeSearch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)
                        Picker("状态", selection: $model.worktreeScope) {
                            ForEach(WorktreeScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                        Spacer()
                        Text("\(model.filteredWorktrees.count) 项")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)

                Divider()

                Table(model.filteredWorktrees, selection: $model.selectedWorktreeID) {
                    TableColumn("仓库 / 分支") { worktree in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(model.displayName(for: worktree))
                                    .fontWeight(.medium)
                                if worktree.isMain {
                                    Image(systemName: "house.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.indigo)
                                        .help("主工作树")
                                }
                                if worktree.isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .help("已锁定")
                                }
                            }
                            Text(worktree.branch)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 120, ideal: 175)

                    TableColumn("路径") { worktree in
                        Text(worktree.path.path.abbreviatingWithTildeInPath)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .help(worktree.path.path)
                    }
                    .width(min: 150, ideal: 250)

                    TableColumn("状态") { worktree in
                        WorktreeStatusPill(worktree: worktree)
                    }
                    .width(min: 80, ideal: 105, max: 125)

                    TableColumn("同步") { worktree in
                        Text(worktree.syncDetail)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(
                                worktree.behindCount > 0 ? Color.orange : Color.secondary
                            )
                    }
                    .width(min: 55, ideal: 70, max: 88)

                    TableColumn("最近活动") { worktree in
                        Text(worktree.lastActivityText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 72, ideal: 100)
                }
                .overlay {
                    if model.filteredWorktrees.isEmpty {
                        EmptyStateView(
                            systemImage: "arrow.triangle.branch",
                            title: model.additionalWorktreeCount == 0 ? "还没有附加工作树" : "没有匹配结果",
                            detail: model.additionalWorktreeCount == 0
                                ? "当前仓库还没有附加工作树，可点击工具栏新建。"
                                : "试试调整搜索词或状态筛选。"
                        )
                    }
                }
            }
            .frame(minWidth: 485, idealWidth: 620)

            if let worktree = model.selectedWorktree {
                WorktreeInspector(model: model, worktree: worktree)
                    .frame(minWidth: 235, idealWidth: 290, maxWidth: 360)
            } else {
                InspectorPlaceholder(
                    systemImage: "cursorarrow.click.2",
                    title: "选择一个工作树",
                    detail: "这里会显示改动、同步状态和常用操作。"
                )
                .frame(minWidth: 215, idealWidth: 250, maxWidth: 310)
            }
        }
    }
}

private struct WorktreeInspector: View {
    @ObservedObject var model: AppModel
    let worktree: WorktreeRecord

    private var linkedPorts: [PortRecord] {
        model.ports.filter { $0.worktreeID == worktree.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: worktree.isMain ? "house.fill" : "arrow.triangle.branch")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                        Spacer()
                        WorktreeStatusPill(worktree: worktree)
                    }
                    Text(worktree.branch)
                        .font(.system(size: 21, weight: .bold, design: .monospaced))
                        .lineLimit(2)
                    Text(model.displayName(for: worktree))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ActionButton(title: "编辑器", systemImage: "chevron.left.forwardslash.chevron.right") {
                        model.openEditor(at: worktree.path)
                    }
                    ActionButton(title: "终端", systemImage: "terminal") {
                        model.openTerminal(at: worktree.path)
                    }
                }
                ActionButton(title: "在访达中显示", systemImage: "folder") {
                    model.reveal(worktree)
                }

                Divider()

                InspectorSection("工作区") {
                    InspectorValueRow(label: "仓库", value: model.displayName(for: worktree))
                    InspectorValueRow(
                        label: "类型",
                        value: worktree.isMain ? "主工作树" : "附加工作树"
                    )
                    InspectorValueRow(label: "状态", value: worktree.statusDetail)
                    InspectorValueRow(label: "最近提交", value: worktree.lastActivityText)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("路径")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(worktree.path.path.abbreviatingWithTildeInPath)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                InspectorSection("Git 同步") {
                    InspectorValueRow(label: "上游", value: worktree.upstream ?? "未设置")
                    InspectorValueRow(label: "领先", value: String(worktree.aheadCount))
                    InspectorValueRow(label: "落后", value: String(worktree.behindCount))
                }

                InspectorSection("关联服务") {
                    if linkedPorts.isEmpty {
                        Text("没有发现从此工作树启动的监听端口。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(linkedPorts) { port in
                            Button {
                                model.showPort(port)
                            } label: {
                                HStack {
                                    Text(":" + String(port.port))
                                        .font(.body.monospaced().weight(.semibold))
                                        .foregroundStyle(.blue)
                                    Text(port.processName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !worktree.isMain {
                    Divider()
                    Button(role: .destructive) {
                        model.requestRemoval(worktree)
                    } label: {
                        Label("移除工作树…", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.isMutating)
                } else {
                    Label("主工作树受保护，不能在 TwigDock 中移除。", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
