import SwiftUI
import UniformTypeIdentifiers

struct OverviewView: View {
    @ObservedObject var model: AppModel

    private var projectPortCount: Int {
        model.ports.filter(\.isProjectPort).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "工作台",
                    subtitle: "把本地端口、进程与 Git 工作树放在同一张地图里。"
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), spacing: 12)],
                    spacing: 12
                ) {
                    MetricCard(
                        title: "监听端口",
                        value: String(model.ports.count),
                        detail: "其中 \(projectPortCount) 个关联项目",
                        systemImage: "antenna.radiowaves.left.and.right",
                        color: .blue
                    )
                    MetricCard(
                        title: "已发现仓库",
                        value: String(model.repositories.count),
                        detail: model.scanRoot?.lastPathComponent ?? "未配置",
                        systemImage: "shippingbox",
                        color: .indigo
                    )
                    MetricCard(
                        title: "附加工作树",
                        value: String(model.additionalWorktreeCount),
                        detail: "不包含仓库主目录",
                        systemImage: "arrow.triangle.branch",
                        color: .teal
                    )
                    MetricCard(
                        title: "待处理改动",
                        value: String(model.dirtyWorktreeCount),
                        detail: model.dirtyWorktreeCount == 0 ? "附加工作树都很干净" : "附加工作树包含未提交改动",
                        systemImage: "exclamationmark.circle",
                        color: model.dirtyWorktreeCount == 0 ? .green : .orange
                    )
                }

                HStack {
                    Text("项目与运行服务")
                        .font(.title3.weight(.semibold))
                    Label("拖动卡片可排序", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("查看全部工作树") {
                        model.selectedSection = .worktrees
                    }
                    .buttonStyle(.link)
                }

                if model.repositories.isEmpty && !model.isRefreshing {
                    EmptyStateView(
                        systemImage: "folder.badge.questionmark",
                        title: model.hasConfiguredScanRoot ? "没有发现 Git 仓库" : "尚未选择代码目录",
                        detail: emptyStateDetail
                    )
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.orderedRepositories) { repository in
                            RepositoryOverviewCard(
                                model: model,
                                repository: repository,
                                worktrees: model.worktrees.filter {
                                    $0.repositoryID == repository.id && !$0.isMain
                                }
                            )
                            .onDrop(
                                of: [UTType.utf8PlainText],
                                delegate: RepositoryDropDelegate(
                                    targetRepositoryID: repository.id,
                                    model: model
                                )
                            )
                        }
                    }
                    .animation(
                        .easeInOut(duration: 0.16),
                        value: model.orderedRepositories.map(\.id)
                    )
                }
            }
            .padding(24)
        }
    }

    private var emptyStateDetail: String {
        guard let scanRoot = model.scanRoot else {
            return "选择一个目录后，TwigDock 才会开始扫描。"
        }
        return "请更改左下角的扫描目录，或在 \(scanRoot.path) 中放入仓库。"
    }
}

private struct RepositoryOverviewCard: View {
    @ObservedObject var model: AppModel
    let repository: RepositoryRecord
    let worktrees: [WorktreeRecord]

    private var primaryWorktree: WorktreeRecord? {
        model.worktrees.first {
            $0.repositoryID == repository.id && $0.isMain
        }
    }

    private var primaryPorts: [PortRecord] {
        guard let primaryWorktree else { return [] }
        return model.ports.filter { $0.worktreeID == primaryWorktree.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.indigo)
                    .frame(width: 34, height: 34)
                    .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName(for: repository))
                        .font(.headline)
                    Text(repository.primaryPath.path.abbreviatingWithTildeInPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(worktrees.count) 个附加工作树")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .padding(4)
                    .contentShape(Rectangle())
                    .help("拖动调整顺序")
                    .onDrag {
                        model.beginDraggingRepository(repository)
                        return NSItemProvider(object: repository.id as NSString)
                    }

                Menu {
                    Button {
                        model.configureRepository(repository)
                    } label: {
                        Label("编辑显示名称…", systemImage: "pencil")
                    }
                    Divider()
                    Button {
                        withAnimation { model.moveRepositoryToTop(repository) }
                    } label: {
                        Label("移到最前面", systemImage: "arrow.up.to.line")
                    }
                    .disabled(!model.canMoveRepository(repository, offset: -1))
                    Button {
                        withAnimation { model.moveRepository(repository, offset: -1) }
                    } label: {
                        Label("上移", systemImage: "arrow.up")
                    }
                    .disabled(!model.canMoveRepository(repository, offset: -1))
                    Button {
                        withAnimation { model.moveRepository(repository, offset: 1) }
                    } label: {
                        Label("下移", systemImage: "arrow.down")
                    }
                    .disabled(!model.canMoveRepository(repository, offset: 1))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(14)

            if !primaryPorts.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    Label("主目录服务", systemImage: "house.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(primaryPorts.prefix(4)) { port in
                        Button("#" + String(port.port)) {
                            model.showPort(port)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.09), in: Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }

            ForEach(worktrees) { worktree in
                Divider()
                HStack(spacing: 12) {
                    Button {
                        model.showWorktree(worktree)
                    } label: {
                        HStack(spacing: 12) {
                        Image(systemName: worktree.isMain ? "house.fill" : "arrow.triangle.branch")
                            .foregroundStyle(worktree.isMain ? Color.indigo : Color.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text(worktree.branch)
                                    .font(.system(.body, design: .monospaced).weight(.medium))
                                if worktree.isMain {
                                    Text("主工作树")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(worktree.path.path.abbreviatingWithTildeInPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 14)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        ForEach(model.ports.filter { $0.worktreeID == worktree.id }.prefix(3)) { port in
                            Button("#" + String(port.port)) {
                                model.showPort(port)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.09), in: Capsule())
                        }
                    }
                    WorktreeStatusPill(worktree: worktree)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

@MainActor
private struct RepositoryDropDelegate: DropDelegate {
    let targetRepositoryID: String
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let sourceID = model.draggedRepositoryID,
              sourceID != targetRepositoryID,
              model.repositoryDragTargetID != targetRepositoryID else { return }
        model.repositoryDragTargetID = targetRepositoryID
        withAnimation(.easeInOut(duration: 0.16)) {
            model.moveRepository(sourceID, before: targetRepositoryID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard model.draggedRepositoryID != nil else { return false }
        model.finishDraggingRepository()
        return true
    }
}
