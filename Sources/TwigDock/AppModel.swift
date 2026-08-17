import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection? = .overview
    @Published var selectedPortID: PortRecord.ID?
    @Published var selectedWorktreeID: WorktreeRecord.ID?

    @Published private(set) var ports: [PortRecord] = []
    @Published private(set) var repositories: [RepositoryRecord] = []
    @Published private(set) var worktrees: [WorktreeRecord] = []
    @Published private(set) var repositoryPreferences = RepositoryPresentationPreferences()
    @Published private(set) var scanRoot: URL?
    @Published private(set) var lastUpdated: Date?

    @Published var portSearch = ""
    @Published var portScope: PortScope = .all
    @Published var worktreeSearch = ""
    @Published var worktreeScope: WorktreeScope = .all

    @Published var isRefreshing = false
    @Published var isMutating = false
    @Published var isShowingNewWorktree = false
    @Published var portAwaitingStop: PortRecord?
    @Published var worktreeAwaitingRemoval: WorktreeRecord?
    @Published var repositoryBeingConfigured: RepositoryRecord?
    @Published var draggedRepositoryID: RepositoryRecord.ID?
    @Published var repositoryDragTargetID: RepositoryRecord.ID?
    @Published var message: AppMessage?

    private static let scanRootKey = "TwigDock.scanRoot"
    private static let repositoryPreferencesKey = "TwigDock.repositoryPreferences"
    private static let legacyScanRootKey = "BranchPort.scanRoot"
    private static let legacyRepositoryPreferencesKey = "BranchPort.repositoryPreferences"
    private let defaults: UserDefaults
    private var monitoringTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: "dev.branchport.mac")
    ) {
        self.defaults = defaults
        Self.migrateLegacyPreferences(from: legacyDefaults, to: defaults)
        scanRoot = ScanRootConfiguration.configuredURL(
            from: defaults.string(forKey: Self.scanRootKey)
        )
        if let data = defaults.data(forKey: Self.repositoryPreferencesKey),
           let value = try? JSONDecoder().decode(
               RepositoryPresentationPreferences.self,
               from: data
           ) {
            repositoryPreferences = value
        }
    }

    static func migrateLegacyPreferences(
        from legacyDefaults: UserDefaults?,
        to defaults: UserDefaults
    ) {
        let keys = [
            (legacy: legacyScanRootKey, current: scanRootKey),
            (legacy: legacyRepositoryPreferencesKey, current: repositoryPreferencesKey)
        ]

        for key in keys where defaults.object(forKey: key.current) == nil {
            let value = defaults.object(forKey: key.legacy)
                ?? legacyDefaults?.object(forKey: key.legacy)
            if let value {
                defaults.set(value, forKey: key.current)
            }
        }
    }

    var orderedRepositories: [RepositoryRecord] {
        let byID = Dictionary(uniqueKeysWithValues: repositories.map { ($0.id, $0) })
        return repositoryPreferences
            .orderedIDs(for: repositories.map(\.id))
            .compactMap { byID[$0] }
    }

    var filteredPorts: [PortRecord] {
        ports.filter { port in
            let matchesScope: Bool
            switch portScope {
            case .all: matchesScope = true
            case .projects: matchesScope = port.isProjectPort
            case .system: matchesScope = !port.isProjectPort
            }

            let query = portSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesScope }
            let haystack = [
                String(port.port), port.processName, String(port.pid), port.command,
                port.projectName ?? "", displayName(for: port),
                port.currentDirectory?.path ?? ""
            ].joined(separator: " ")
            return matchesScope && haystack.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredWorktrees: [WorktreeRecord] {
        worktrees.filter { !$0.isMain }.filter { worktree in
            let matchesScope: Bool
            switch worktreeScope {
            case .all: matchesScope = true
            case .dirty: matchesScope = worktree.status == .dirty
            case .clean: matchesScope = worktree.status == .clean
            case .stale: matchesScope = worktree.status == .stale
            }

            let query = worktreeSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesScope }
            let haystack = [
                worktree.repositoryName, displayName(for: worktree),
                worktree.branch, worktree.path.path,
                worktree.upstream ?? ""
            ].joined(separator: " ")
            return matchesScope && haystack.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedPort: PortRecord? {
        ports.first { $0.id == selectedPortID }
    }

    var selectedWorktree: WorktreeRecord? {
        worktrees.first { $0.id == selectedWorktreeID }
    }

    var dirtyWorktreeCount: Int {
        worktrees.filter { !$0.isMain && $0.status == .dirty }.count
    }

    var additionalWorktreeCount: Int {
        worktrees.filter { !$0.isMain }.count
    }

    var linkedProjectCount: Int {
        Set(ports.compactMap(\.repositoryIdentifier)).count
    }

    var hasConfiguredScanRoot: Bool {
        scanRoot != nil
    }

    var menuBarContent: MenuBarContentSnapshot {
        MenuBarContentSnapshot(
            ports: ports,
            worktrees: worktrees,
            orderedRepositoryIDs: orderedRepositories.map(\.id)
        )
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            if let self, self.hasConfiguredScanRoot {
                await self.refreshAll()
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    return
                }
                guard let self else { return }
                await self.refreshPorts(silently: true)
            }
        }
    }

    func refreshAll() async {
        guard let root = scanRoot, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let portTask = Task.detached(priority: .userInitiated) {
            try PortService().scan()
        }
        let gitTask = Task.detached(priority: .userInitiated) {
            try GitWorktreeService().scan(root: root)
        }

        var scannedPorts: [PortRecord]?
        var snapshot: GitSnapshot?
        var errors: [String] = []

        do {
            scannedPorts = try await portTask.value
            if let scannedPorts {
                ports = Self.link(scannedPorts, to: worktrees)
                normalizeSelection()
                lastUpdated = Date()
            }
        } catch {
            errors.append("端口扫描：\(error.localizedDescription)")
        }
        do {
            snapshot = try await gitTask.value
        } catch {
            errors.append("工作树扫描：\(error.localizedDescription)")
        }

        if let snapshot {
            repositories = snapshot.repositories
            worktrees = snapshot.worktrees
            reconcileRepositoryPreferences()
        }
        if let scannedPorts {
            ports = Self.link(scannedPorts, to: worktrees)
        } else if snapshot != nil {
            ports = Self.link(ports, to: worktrees)
        }
        normalizeSelection()
        lastUpdated = Date()

        if !errors.isEmpty {
            message = AppMessage(
                kind: .error,
                title: "部分数据加载失败",
                detail: errors.joined(separator: "\n")
            )
        }
    }

    func refreshPorts(silently: Bool = false) async {
        guard scanRoot != nil, !isRefreshing && !isMutating else { return }
        do {
            let scanned = try await Task.detached(priority: .utility) {
                try PortService().scan()
            }.value
            ports = Self.link(scanned, to: worktrees)
            normalizeSelection()
            lastUpdated = Date()
        } catch {
            if !silently {
                show(error: error, title: "端口刷新失败")
            }
        }
    }

    func requestStop(_ port: PortRecord) {
        portAwaitingStop = port
    }

    func stopAwaitingPort() async {
        guard let port = portAwaitingStop else { return }
        portAwaitingStop = nil
        isMutating = true
        defer { isMutating = false }

        do {
            try await Task.detached(priority: .userInitiated) {
                try PortService().stop(pid: port.pid)
            }.value
            try? await Task.sleep(nanoseconds: 350_000_000)
            await refreshPorts(silently: true)
            message = AppMessage(
                kind: .information,
                title: "已发送停止信号",
                detail: "已向 \(port.processName)（PID \(port.pid)）发送 SIGTERM。"
            )
        } catch {
            show(error: error, title: "停止进程失败")
        }
    }

    func createWorktree(
        repository: RepositoryRecord,
        baseBranch: String,
        newBranch: String,
        destinationPath: String,
        copyEnvironmentFiles: Bool
    ) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }

        let request = WorktreeCreationRequest(
            repository: repository,
            baseBranch: baseBranch,
            newBranch: newBranch.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: URL(
                fileURLWithPath: (destinationPath as NSString).expandingTildeInPath,
                isDirectory: true
            ).standardizedFileURL,
            copyEnvironmentFiles: copyEnvironmentFiles
        )

        do {
            let copied = try await Task.detached(priority: .userInitiated) {
                try GitWorktreeService().createWorktree(request)
            }.value
            await refreshAllAfterMutation()
            let copyDetail = copied.isEmpty ? "" : "\n已复制：\(copied.joined(separator: "、"))"
            message = AppMessage(
                kind: .information,
                title: "工作树已创建",
                detail: "\(request.newBranch)\n\(request.destination.path)\(copyDetail)"
            )
            return true
        } catch {
            show(error: error, title: "创建工作树失败")
            return false
        }
    }

    func requestRemoval(_ worktree: WorktreeRecord) {
        guard !worktree.isMain else {
            message = AppMessage(
                kind: .information,
                title: "这是主工作树",
                detail: "为避免破坏仓库入口，TwigDock 不提供主工作树移除操作。"
            )
            return
        }
        worktreeAwaitingRemoval = worktree
    }

    func removeWorktree(
        _ worktree: WorktreeRecord,
        force: Bool,
        stopLinkedProcesses: Bool,
        deleteBranch: Bool
    ) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }

        let request = WorktreeRemovalRequest(
            worktree: worktree,
            force: force,
            stopLinkedProcesses: stopLinkedProcesses,
            deleteBranch: deleteBranch
        )
        let linkedPIDs = Set(
            ports.filter { $0.worktreeID == worktree.id }.map(\.pid)
        )

        do {
            try await Task.detached(priority: .userInitiated) {
                if request.stopLinkedProcesses {
                    for pid in linkedPIDs.sorted() {
                        try PortService().stop(pid: pid)
                    }
                }
                try GitWorktreeService().removeWorktree(request)
            }.value
            worktreeAwaitingRemoval = nil
            selectedWorktreeID = nil
            await refreshAllAfterMutation()
            message = AppMessage(
                kind: .information,
                title: "工作树已移除",
                detail: "已移除 \(worktree.branch)。原仓库中的提交不会受到影响。"
            )
            return true
        } catch {
            await refreshAllAfterMutation()
            show(error: error, title: "移除工作树失败")
            return false
        }
    }

    func chooseScanRoot() {
        let panel = NSOpenPanel()
        panel.title = "选择 Git 仓库扫描目录"
        panel.prompt = "选择"
        panel.directoryURL = scanRoot
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selected = panel.url else { return }
        let normalizedRoot = selected.standardizedFileURL
        scanRoot = normalizedRoot
        defaults.set(normalizedRoot.path, forKey: Self.scanRootKey)
        Task { await refreshAll() }
    }

    func showPort(_ port: PortRecord) {
        selectedPortID = port.id
        selectedSection = .ports
    }

    func showWorktree(_ worktree: WorktreeRecord) {
        selectedWorktreeID = worktree.id
        selectedSection = .worktrees
    }

    func displayName(for repository: RepositoryRecord) -> String {
        repositoryPreferences.displayName(
            canonicalName: repository.name,
            repositoryID: repository.id
        )
    }

    func displayName(for worktree: WorktreeRecord) -> String {
        repositoryPreferences.displayName(
            canonicalName: worktree.repositoryName,
            repositoryID: worktree.repositoryID
        )
    }

    func displayName(for port: PortRecord) -> String {
        guard let worktreeID = port.worktreeID,
              let worktree = worktrees.first(where: { $0.id == worktreeID }) else {
            return port.projectName ?? "未关联"
        }
        return displayName(for: worktree)
    }

    func repositoryAlias(for repository: RepositoryRecord) -> String {
        repositoryPreferences.aliases[repository.id] ?? ""
    }

    func configureRepository(_ repository: RepositoryRecord) {
        repositoryBeingConfigured = repository
    }

    func setRepositoryAlias(_ alias: String, for repository: RepositoryRecord) {
        repositoryPreferences.setAlias(alias, for: repository.id)
        persistRepositoryPreferences()
    }

    func beginDraggingRepository(_ repository: RepositoryRecord) {
        draggedRepositoryID = repository.id
        repositoryDragTargetID = nil
    }

    func finishDraggingRepository() {
        draggedRepositoryID = nil
        repositoryDragTargetID = nil
    }

    func moveRepository(_ sourceID: String, before targetID: String) {
        repositoryPreferences.move(
            sourceID,
            before: targetID,
            availableIDs: orderedRepositories.map(\.id)
        )
        persistRepositoryPreferences()
    }

    func moveRepository(_ repository: RepositoryRecord, offset: Int) {
        repositoryPreferences.move(
            repository.id,
            offset: offset,
            availableIDs: orderedRepositories.map(\.id)
        )
        persistRepositoryPreferences()
    }

    func moveRepositoryToTop(_ repository: RepositoryRecord) {
        repositoryPreferences.moveToTop(
            repository.id,
            availableIDs: orderedRepositories.map(\.id)
        )
        persistRepositoryPreferences()
    }

    func canMoveRepository(_ repository: RepositoryRecord, offset: Int) -> Bool {
        guard let index = orderedRepositories.firstIndex(where: { $0.id == repository.id }) else {
            return false
        }
        return orderedRepositories.indices.contains(index + offset)
    }

    func openInBrowser(_ port: PortRecord) {
        guard let url = port.browserURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyAddress(_ port: PortRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(port.address, forType: .string)
        message = AppMessage(
            kind: .information,
            title: "地址已复制",
            detail: port.address
        )
    }

    func reveal(_ worktree: WorktreeRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([worktree.path])
    }

    func openTerminal(at directory: URL) {
        openApplication("Terminal", at: directory)
    }

    func openEditor(at directory: URL) {
        let codeApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        if codeApp != nil {
            openApplication("Visual Studio Code", at: directory)
        } else {
            NSWorkspace.shared.open(directory)
        }
    }

    private func openApplication(_ application: String, at directory: URL) {
        Task.detached(priority: .utility) {
            _ = try? CommandRunner().run(
                "/usr/bin/open",
                arguments: ["-a", application, directory.path]
            )
        }
    }

    private func refreshAllAfterMutation() async {
        guard let root = scanRoot else { return }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let snapshot = try GitWorktreeService().scan(root: root)
                let ports = try PortService().scan()
                return (snapshot, ports)
            }.value
            repositories = result.0.repositories
            worktrees = result.0.worktrees
            reconcileRepositoryPreferences()
            ports = Self.link(result.1, to: worktrees)
            normalizeSelection()
            lastUpdated = Date()
        } catch {
            show(error: error, title: "刷新数据失败")
        }
    }

    private func normalizeSelection() {
        if let selectedPortID, !ports.contains(where: { $0.id == selectedPortID }) {
            self.selectedPortID = nil
        }
        if let selectedWorktreeID, !worktrees.contains(where: { $0.id == selectedWorktreeID }) {
            self.selectedWorktreeID = nil
        }
    }

    private func reconcileRepositoryPreferences() {
        let previous = repositoryPreferences
        repositoryPreferences.reconcile(availableIDs: repositories.map(\.id))
        if repositoryPreferences != previous {
            persistRepositoryPreferences()
        }
    }

    private func persistRepositoryPreferences() {
        guard let data = try? JSONEncoder().encode(repositoryPreferences) else { return }
        defaults.set(data, forKey: Self.repositoryPreferencesKey)
    }

    private func show(error: Error, title: String) {
        message = AppMessage(kind: .error, title: title, detail: error.localizedDescription)
    }

    private static func link(
        _ ports: [PortRecord],
        to worktrees: [WorktreeRecord]
    ) -> [PortRecord] {
        let candidates = worktrees.sorted { $0.path.path.count > $1.path.path.count }
        return ports.map { port in
            guard let directory = port.currentDirectory?.standardizedFileURL.path,
                  let worktree = candidates.first(where: {
                      directory == $0.path.path || directory.hasPrefix($0.path.path + "/")
                  }) else { return port }
            var linked = port
            linked.projectName = worktree.repositoryName
            linked.worktreeID = worktree.id
            return linked
        }
    }
}

private extension PortRecord {
    var repositoryIdentifier: String? {
        projectName
    }
}
