import Foundation

enum ScanRootConfiguration {
    static func configuredURL(from storedPath: String?) -> URL? {
        guard let path = storedPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              (path as NSString).isAbsolutePath else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case ports
    case worktrees

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "总览"
        case .ports: "端口"
        case .worktrees: "工作树"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .ports: "antenna.radiowaves.left.and.right"
        case .worktrees: "arrow.triangle.branch"
        }
    }
}

enum PortScope: String, CaseIterable, Identifiable {
    case all
    case projects
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部端口"
        case .projects: "项目端口"
        case .system: "系统服务"
        }
    }
}

enum WorktreeScope: String, CaseIterable, Identifiable {
    case all
    case dirty
    case clean
    case stale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部状态"
        case .dirty: "有改动"
        case .clean: "无改动"
        case .stale: "长期未使用"
        }
    }
}

struct PortRecord: Identifiable, Hashable, Sendable {
    let id: String
    let port: Int
    let processName: String
    let pid: Int32
    let protocolName: String
    let localAddress: String
    let state: String
    let runtime: String
    let command: String
    let elapsed: String
    let currentDirectory: URL?
    var projectName: String?
    var worktreeID: String?

    var address: String {
        "localhost:\(port)"
    }

    var browserURL: URL? {
        guard protocolName == "TCP" else { return nil }
        return URL(string: "http://localhost:\(port)")
    }

    var isProjectPort: Bool {
        worktreeID != nil
    }
}

enum WorktreeStatus: String, Sendable {
    case clean
    case dirty
    case stale

    var title: String {
        switch self {
        case .clean: "无改动"
        case .dirty: "有改动"
        case .stale: "长期未使用"
        }
    }
}

struct WorktreeRecord: Identifiable, Hashable, Sendable {
    let id: String
    let repositoryID: String
    let repositoryName: String
    let repositoryPath: URL
    let branch: String
    let path: URL
    let isMain: Bool
    let isLocked: Bool
    let isPrunable: Bool
    let changeCount: Int
    let aheadCount: Int
    let behindCount: Int
    let upstream: String?
    let lastCommitDate: Date?

    var status: WorktreeStatus {
        if changeCount > 0 { return .dirty }
        if isPrunable { return .stale }
        if let lastCommitDate,
           Date().timeIntervalSince(lastCommitDate) > 14 * 24 * 60 * 60,
           !isMain {
            return .stale
        }
        return .clean
    }

    var statusDetail: String {
        switch status {
        case .dirty: "\(changeCount) 项改动"
        case .stale: isPrunable ? "路径已失效" : "长期未使用"
        case .clean: "无改动"
        }
    }

    var syncDetail: String {
        var values: [String] = []
        if aheadCount > 0 { values.append("↑\(aheadCount)") }
        if behindCount > 0 { values.append("↓\(behindCount)") }
        return values.isEmpty ? "已同步" : values.joined(separator: " ")
    }

    var lastActivityText: String {
        guard let lastCommitDate else { return "暂无提交" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastCommitDate, relativeTo: Date())
    }
}

struct RepositoryRecord: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let primaryPath: URL
    let commonGitDirectory: URL
    let branches: [String]
}

struct MenuBarContentSnapshot: Sendable {
    let projectPorts: [PortRecord]
    let additionalWorktrees: [WorktreeRecord]

    init(
        ports: [PortRecord],
        worktrees: [WorktreeRecord],
        orderedRepositoryIDs: [RepositoryRecord.ID]
    ) {
        let repositoryRanks = Dictionary(
            uniqueKeysWithValues: orderedRepositoryIDs.enumerated().map { ($1, $0) }
        )
        let worktreesByID = Dictionary(uniqueKeysWithValues: worktrees.map { ($0.id, $0) })

        func rank(for worktree: WorktreeRecord) -> Int {
            repositoryRanks[worktree.repositoryID] ?? Int.max
        }

        func rank(for port: PortRecord) -> Int {
            guard let worktreeID = port.worktreeID,
                  let worktree = worktreesByID[worktreeID] else { return Int.max }
            return rank(for: worktree)
        }

        projectPorts = ports
            .filter(\.isProjectPort)
            .sorted { lhs, rhs in
                let lhsRank = rank(for: lhs)
                let rhsRank = rank(for: rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if lhs.port != rhs.port { return lhs.port < rhs.port }
                return lhs.id < rhs.id
            }

        additionalWorktrees = worktrees
            .filter { !$0.isMain }
            .sorted { lhs, rhs in
                let lhsRank = rank(for: lhs)
                let rhsRank = rank(for: rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if lhs.repositoryName != rhs.repositoryName {
                    return lhs.repositoryName.localizedCaseInsensitiveCompare(
                        rhs.repositoryName
                    ) == .orderedAscending
                }
                if lhs.branch != rhs.branch {
                    return lhs.branch.localizedCaseInsensitiveCompare(rhs.branch) == .orderedAscending
                }
                return lhs.id < rhs.id
            }
    }
}

struct RepositoryPresentationPreferences: Codable, Equatable, Sendable {
    var order: [String]
    var aliases: [String: String]

    init(order: [String] = [], aliases: [String: String] = [:]) {
        self.order = order
        self.aliases = aliases
    }

    func orderedIDs(for availableIDs: [String]) -> [String] {
        let available = Set(availableIDs)
        let retained = order.filter(available.contains)
        let retainedSet = Set(retained)
        return retained + availableIDs.filter { !retainedSet.contains($0) }
    }

    mutating func reconcile(availableIDs: [String]) {
        order = orderedIDs(for: availableIDs)
    }

    mutating func move(
        _ sourceID: String,
        before targetID: String,
        availableIDs: [String]
    ) {
        guard sourceID != targetID else { return }
        var values = orderedIDs(for: availableIDs)
        guard let sourceIndex = values.firstIndex(of: sourceID),
              let targetIndex = values.firstIndex(of: targetID) else { return }
        let source = values.remove(at: sourceIndex)
        values.insert(source, at: min(targetIndex, values.endIndex))
        order = values
    }

    mutating func move(_ repositoryID: String, offset: Int, availableIDs: [String]) {
        var values = orderedIDs(for: availableIDs)
        guard let sourceIndex = values.firstIndex(of: repositoryID) else { return }
        let targetIndex = sourceIndex + offset
        guard values.indices.contains(targetIndex) else { return }
        values.swapAt(sourceIndex, targetIndex)
        order = values
    }

    mutating func moveToTop(_ repositoryID: String, availableIDs: [String]) {
        var values = orderedIDs(for: availableIDs)
        guard let index = values.firstIndex(of: repositoryID), index > 0 else { return }
        let value = values.remove(at: index)
        values.insert(value, at: 0)
        order = values
    }

    mutating func setAlias(_ alias: String, for repositoryID: String) {
        let value = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            aliases.removeValue(forKey: repositoryID)
        } else {
            aliases[repositoryID] = value
        }
    }

    func displayName(canonicalName: String, repositoryID: String) -> String {
        guard let alias = aliases[repositoryID], !alias.isEmpty else {
            return canonicalName
        }
        return "\(canonicalName)（\(alias)）"
    }
}

struct AppMessage: Identifiable, Equatable {
    enum Kind {
        case error
        case information
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
}

struct WorktreeCreationRequest: Sendable {
    let repository: RepositoryRecord
    let baseBranch: String
    let newBranch: String
    let destination: URL
    let copyEnvironmentFiles: Bool
}

struct WorktreeRemovalRequest: Sendable {
    let worktree: WorktreeRecord
    let force: Bool
    let stopLinkedProcesses: Bool
    let deleteBranch: Bool
}
