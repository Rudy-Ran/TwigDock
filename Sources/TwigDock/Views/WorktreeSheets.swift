import AppKit
import SwiftUI

struct NewWorktreeSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var repositoryID = ""
    @State private var baseBranch = "HEAD"
    @State private var newBranch = ""
    @State private var destinationPath = ""
    @State private var copyEnvironmentFiles = true
    @State private var destinationWasEdited = false

    private var repository: RepositoryRecord? {
        model.repositories.first { $0.id == repositoryID }
    }

    private var canSubmit: Bool {
        repository != nil
            && !baseBranch.isEmpty
            && !newBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.isMutating
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("新建工作树")
                        .font(.title2.weight(.bold))
                    Text("从现有分支创建一个独立的本地工作目录。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Divider()

            Form {
                Section("来源") {
                    Picker("仓库", selection: $repositoryID) {
                        ForEach(model.repositories) { repository in
                            Text(model.displayName(for: repository)).tag(repository.id)
                        }
                    }

                    Picker("基于", selection: $baseBranch) {
                        Text("当前 HEAD").tag("HEAD")
                        if let repository {
                            ForEach(repository.branches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                    }
                }

                Section("新工作树") {
                    TextField("新分支", text: $newBranch, prompt: Text("例如 feature/login"))

                    HStack {
                        TextField(
                            "保存位置",
                            text: Binding(
                                get: { destinationPath },
                                set: {
                                    destinationPath = $0
                                    destinationWasEdited = true
                                }
                            )
                        )
                        Button("选择父目录…") {
                            chooseParentDirectory()
                        }
                    }
                    Text("TwigDock 会创建此目录；已有的非空目录不会被覆盖。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("初始化") {
                    Toggle("复制常用环境文件（.env、.env.local 等）", isOn: $copyEnvironmentFiles)
                    Text("只复制主工作树中已存在的文件，且不会覆盖目标文件。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                if model.isMutating {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在创建…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("创建工作树") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
            .padding(16)
        }
        .frame(width: 590, height: 520)
        .onAppear {
            guard repositoryID.isEmpty, let first = model.repositories.first else { return }
            repositoryID = first.id
            configure(for: first)
        }
        .onChange(of: repositoryID) { newValue in
            guard let repository = model.repositories.first(where: { $0.id == newValue }) else { return }
            destinationWasEdited = false
            configure(for: repository)
        }
        .onChange(of: newBranch) { _ in
            guard !destinationWasEdited, let repository else { return }
            destinationPath = suggestedDestination(for: repository)
        }
    }

    private func configure(for repository: RepositoryRecord) {
        baseBranch = model.worktrees.first {
            $0.repositoryID == repository.id && $0.isMain
        }?.branch ?? repository.branches.first ?? "HEAD"
        destinationPath = suggestedDestination(for: repository)
    }

    private func suggestedDestination(for repository: RepositoryRecord) -> String {
        let raw = newBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = raw.isEmpty
            ? "new-worktree"
            : raw.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "-")
        return repository.primaryPath
            .deletingLastPathComponent()
            .appendingPathComponent("\(repository.name)-\(slug)", isDirectory: true)
            .path
    }

    private func chooseParentDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择工作树的父目录"
        panel.prompt = "选择"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = repository?.primaryPath.deletingLastPathComponent()

        guard panel.runModal() == .OK, let parent = panel.url, let repository else { return }
        let suggestedName = URL(fileURLWithPath: suggestedDestination(for: repository)).lastPathComponent
        destinationPath = parent.appendingPathComponent(suggestedName, isDirectory: true).path
        destinationWasEdited = true
    }

    private func submit() {
        guard let repository else { return }
        Task {
            let succeeded = await model.createWorktree(
                repository: repository,
                baseBranch: baseBranch,
                newBranch: newBranch,
                destinationPath: destinationPath,
                copyEnvironmentFiles: copyEnvironmentFiles
            )
            if succeeded {
                model.isShowingNewWorktree = false
                dismiss()
            }
        }
    }
}

struct RemoveWorktreeSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let worktree: WorktreeRecord

    @State private var force = false
    @State private var stopLinkedProcesses = true
    @State private var deleteBranch = false
    @State private var confirmation = ""
    @State private var didCopyName = false

    private var linkedPortCount: Int {
        model.ports.filter { $0.worktreeID == worktree.id }.count
    }

    private var isDirty: Bool {
        worktree.changeCount > 0
    }

    private var canRemove: Bool {
        !model.isMutating && (!isDirty || (force && confirmation == worktree.branch))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("移除工作树")
                        .font(.title2.weight(.bold))
                    Text("此操作会删除工作树目录，但不会删除仓库提交。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(worktree.branch)
                            .font(.headline.monospaced())
                            .textSelection(.enabled)
                        Text(worktree.path.path.abbreviatingWithTildeInPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Button {
                        copyWorktreeName()
                    } label: {
                        Label(
                            didCopyName ? "已复制" : "复制名称",
                            systemImage: didCopyName ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("复制分支名")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))

                if isDirty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            "此工作树有 \(worktree.changeCount) 项未提交改动",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.orange)

                        HighlightedCheckboxRow(
                            title: "我了解未提交改动将丢失，并强制移除",
                            tint: .orange,
                            isOn: $force
                        )
                        TextField("输入分支名 \(worktree.branch) 以确认", text: $confirmation)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!force)
                            .opacity(force ? 1 : 0.55)
                    }
                    .padding(13)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Label("工作目录没有未提交改动。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                HighlightedCheckboxRow(
                    title: "先停止关联进程（\(linkedPortCount) 个监听端口）",
                    tint: .blue,
                    isEnabled: linkedPortCount > 0,
                    isOn: $stopLinkedProcesses
                )

                if worktree.branch.hasPrefix("游离 HEAD") {
                    Label("此工作树处于游离 HEAD，没有关联的本地分支。", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HighlightedCheckboxRow(
                        title: "同时删除本地分支 \(worktree.branch)",
                        detail: "不会删除远端分支；未推送的提交可能失去分支引用。",
                        tint: .red,
                        isOn: $deleteBranch
                    )
                }
            }
            .padding(22)

            Spacer(minLength: 0)
            Divider()

            HStack {
                if model.isMutating {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在移除…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("取消") {
                        model.worktreeAwaitingRemoval = nil
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                    Button("移除工作树", role: .destructive) {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRemove)
                }
                .controlSize(.regular)
                .fixedSize()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(width: 570, height: isDirty ? 550 : 470)
        .onAppear {
            force = worktree.isPrunable
            if linkedPortCount == 0 { stopLinkedProcesses = false }
        }
    }

    private func submit() {
        Task {
            let succeeded = await model.removeWorktree(
                worktree,
                force: force,
                stopLinkedProcesses: stopLinkedProcesses,
                deleteBranch: deleteBranch
            )
            if succeeded { dismiss() }
        }
    }

    private func copyWorktreeName() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(worktree.branch, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            didCopyName = true
        }
    }
}

private struct HighlightedCheckboxRow: View {
    let title: String
    var detail: String? = nil
    let tint: Color
    var isEnabled = true
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        } label: {
            HStack(alignment: detail == nil ? .center : .top, spacing: 10) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn ? tint : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .background(
            isOn ? tint.opacity(0.11) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    isOn ? tint.opacity(0.55) : Color.primary.opacity(0.08),
                    lineWidth: isOn ? 1.5 : 1
                )
        }
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "已选择" : "未选择")
    }
}
