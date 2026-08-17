import Foundation

struct GitSnapshot: Sendable {
    let repositories: [RepositoryRecord]
    let worktrees: [WorktreeRecord]
}

struct ParsedWorktree: Equatable, Sendable {
    let path: String
    let branch: String
    let isBare: Bool
    let isDetached: Bool
    let isLocked: Bool
    let isPrunable: Bool
}

struct ParsedGitStatus: Equatable, Sendable {
    let changeCount: Int
    let aheadCount: Int
    let behindCount: Int
    let upstream: String?
}

private struct WorktreeSeed: Sendable {
    let repository: RepositoryRecord
    let item: ParsedWorktree
    let isMain: Bool
}

private final class WorktreeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [WorktreeRecord] = []

    func append(_ value: WorktreeRecord) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [WorktreeRecord] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

enum GitWorktreeError: LocalizedError {
    case scanRootMissing(String)
    case invalidBranch(String)
    case destinationNotEmpty(String)
    case mainWorktreeRemoval
    case branchDeletionFailed(branch: String, detail: String)

    var errorDescription: String? {
        switch self {
        case let .scanRootMissing(path): "扫描目录不存在：\(path)"
        case let .invalidBranch(branch): "分支名称无效：\(branch)"
        case let .destinationNotEmpty(path): "目标目录不是空目录：\(path)"
        case .mainWorktreeRemoval: "主工作树不能从这里移除。"
        case let .branchDeletionFailed(branch, detail):
            "工作树已移除，但本地分支 \(branch) 删除失败：\(detail)"
        }
    }
}

struct GitWorktreeService: Sendable {
    private let runner = CommandRunner()
    private var fileManager: FileManager { .default }

    func scan(root: URL, maximumDepth: Int = 4) throws -> GitSnapshot {
        guard fileManager.fileExists(atPath: root.path) else {
            throw GitWorktreeError.scanRootMissing(root.path)
        }

        let candidates = discoverRepositories(root: root, maximumDepth: maximumDepth)
        var groups: [String: URL] = [:]

        for candidate in candidates {
            guard let commonDirectory = try? commonGitDirectory(for: candidate) else { continue }
            groups[commonDirectory.path] = candidate
        }

        var repositories: [RepositoryRecord] = []
        var seeds: [WorktreeSeed] = []

        for key in groups.keys.sorted() {
            guard let candidate = groups[key] else { continue }
            let commonDirectory = URL(fileURLWithPath: key).standardizedFileURL
            let listed = try runner.runSuccessful(
                "/usr/bin/git",
                arguments: ["worktree", "list", "--porcelain"],
                currentDirectory: candidate
            )
            let parsed = parseWorktreeList(listed).filter { !$0.isBare }
            guard let main = parsed.first else { continue }

            let repositoryID = commonDirectory.path
            let mainPath = URL(fileURLWithPath: main.path).standardizedFileURL
            let repository = RepositoryRecord(
                id: repositoryID,
                name: mainPath.lastPathComponent,
                primaryPath: mainPath,
                commonGitDirectory: commonDirectory,
                branches: branches(in: mainPath)
            )
            repositories.append(repository)

            for (index, item) in parsed.enumerated() {
                seeds.append(
                    WorktreeSeed(
                        repository: repository,
                        item: item,
                        isMain: index == 0
                    )
                )
            }
        }

        let collector = WorktreeCollector()
        let queue = OperationQueue()
        queue.name = "dev.twigdock.git-metadata"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = min(4, max(1, ProcessInfo.processInfo.processorCount))

        for seed in seeds {
            queue.addOperation {
                let path = URL(fileURLWithPath: seed.item.path).standardizedFileURL
                let status = seed.isMain
                    ? ParsedGitStatus(
                        changeCount: 0,
                        aheadCount: 0,
                        behindCount: 0,
                        upstream: nil
                    )
                    : status(at: path)
                let record = WorktreeRecord(
                    id: path.path,
                    repositoryID: seed.repository.id,
                    repositoryName: seed.repository.name,
                    repositoryPath: seed.repository.primaryPath,
                    branch: seed.item.branch,
                    path: path,
                    isMain: seed.isMain,
                    isLocked: seed.item.isLocked,
                    isPrunable: seed.item.isPrunable,
                    changeCount: status.changeCount,
                    aheadCount: status.aheadCount,
                    behindCount: status.behindCount,
                    upstream: status.upstream,
                    lastCommitDate: seed.isMain ? nil : lastCommitDate(at: path)
                )
                collector.append(record)
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        let worktrees = collector.snapshot()

        return GitSnapshot(
            repositories: repositories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            worktrees: worktrees.sorted {
                if $0.repositoryName == $1.repositoryName {
                    if $0.isMain != $1.isMain { return $0.isMain }
                    return $0.branch.localizedStandardCompare($1.branch) == .orderedAscending
                }
                return $0.repositoryName.localizedStandardCompare($1.repositoryName) == .orderedAscending
            }
        )
    }

    func createWorktree(_ request: WorktreeCreationRequest) throws -> [String] {
        let validation = try runner.run(
            "/usr/bin/git",
            arguments: ["check-ref-format", "--branch", request.newBranch],
            currentDirectory: request.repository.primaryPath
        )
        guard validation.exitCode == 0 else {
            throw GitWorktreeError.invalidBranch(request.newBranch)
        }

        if fileManager.fileExists(atPath: request.destination.path),
           let contents = try? fileManager.contentsOfDirectory(atPath: request.destination.path),
           !contents.isEmpty {
            throw GitWorktreeError.destinationNotEmpty(request.destination.path)
        }

        try fileManager.createDirectory(
            at: request.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = try runner.runSuccessful(
            "/usr/bin/git",
            arguments: [
                "worktree", "add", "-b", request.newBranch,
                request.destination.path, request.baseBranch
            ],
            currentDirectory: request.repository.primaryPath
        )

        guard request.copyEnvironmentFiles else { return [] }
        return copyEnvironmentFiles(
            from: request.repository.primaryPath,
            to: request.destination
        )
    }

    func removeWorktree(_ request: WorktreeRemovalRequest) throws {
        guard !request.worktree.isMain else {
            throw GitWorktreeError.mainWorktreeRemoval
        }

        var arguments = ["worktree", "remove"]
        if request.force { arguments.append("--force") }
        arguments.append(request.worktree.path.path)
        _ = try runner.runSuccessful(
            "/usr/bin/git",
            arguments: arguments,
            currentDirectory: request.worktree.repositoryPath
        )

        if request.deleteBranch, !request.worktree.branch.hasPrefix("游离 HEAD") {
            do {
                _ = try runner.runSuccessful(
                    "/usr/bin/git",
                    arguments: ["branch", "-D", request.worktree.branch],
                    currentDirectory: request.worktree.repositoryPath
                )
            } catch {
                throw GitWorktreeError.branchDeletionFailed(
                    branch: request.worktree.branch,
                    detail: error.localizedDescription
                )
            }
        }
    }

    func parseWorktreeList(_ output: String) -> [ParsedWorktree] {
        var result: [ParsedWorktree] = []
        var path: String?
        var branch = "游离 HEAD"
        var isBare = false
        var isDetached = false
        var isLocked = false
        var isPrunable = false

        func appendCurrent() {
            guard let path else { return }
            result.append(
                ParsedWorktree(
                    path: path,
                    branch: branch,
                    isBare: isBare,
                    isDetached: isDetached,
                    isLocked: isLocked,
                    isPrunable: isPrunable
                )
            )
        }

        for line in (output + "\n").split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let value = String(line)
            if value.isEmpty {
                appendCurrent()
                path = nil
                branch = "游离 HEAD"
                isBare = false
                isDetached = false
                isLocked = false
                isPrunable = false
            } else if value.hasPrefix("worktree ") {
                path = String(value.dropFirst("worktree ".count))
            } else if value.hasPrefix("branch ") {
                branch = String(value.dropFirst("branch refs/heads/".count))
            } else if value == "bare" {
                isBare = true
            } else if value == "detached" {
                isDetached = true
            } else if value.hasPrefix("locked") {
                isLocked = true
            } else if value.hasPrefix("prunable") {
                isPrunable = true
            }
        }
        return result
    }

    func parseStatus(_ output: String) -> ParsedGitStatus {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let header = lines.first?.hasPrefix("## ") == true ? lines[0] : ""
        let changeCount = header.isEmpty ? lines.count : max(0, lines.count - 1)
        return ParsedGitStatus(
            changeCount: changeCount,
            aheadCount: Self.counter(named: "ahead", in: header),
            behindCount: Self.counter(named: "behind", in: header),
            upstream: Self.upstream(in: header)
        )
    }

    private func discoverRepositories(root: URL, maximumDepth: Int) -> [URL] {
        var values: [URL] = []
        let root = root.standardizedFileURL
        var pending: [(url: URL, depth: Int)] = [(root, 0)]
        var nextIndex = 0

        func hasGitEntry(_ directory: URL) -> Bool {
            fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path)
        }

        let skippedNames: Set<String> = [
            "node_modules", "vendor", "Pods", "DerivedData", ".build",
            "build", "dist", ".next", "coverage", ".swiftpm"
        ]
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey
        ]

        while nextIndex < pending.count {
            let current = pending[nextIndex]
            nextIndex += 1

            if hasGitEntry(current.url) {
                values.append(current.url.standardizedFileURL)
                continue
            }
            guard current.depth < maximumDepth,
                  let children = try? fileManager.contentsOfDirectory(
                    at: current.url,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles]
                  ) else { continue }

            for child in children {
                guard !skippedNames.contains(child.lastPathComponent),
                      let properties = try? child.resourceValues(forKeys: resourceKeys),
                      properties.isDirectory == true,
                      properties.isSymbolicLink != true,
                      properties.isPackage != true else { continue }
                pending.append((child.standardizedFileURL, current.depth + 1))
            }
        }
        return values
    }

    private func commonGitDirectory(for repository: URL) throws -> URL {
        let value = try runner.runSuccessful(
            "/usr/bin/git",
            arguments: ["rev-parse", "--path-format=absolute", "--git-common-dir"],
            currentDirectory: repository
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: value).standardizedFileURL
    }

    private func branches(in repository: URL) -> [String] {
        let output = try? runner.runSuccessful(
            "/usr/bin/git",
            arguments: ["branch", "--format=%(refname:short)"],
            currentDirectory: repository
        )
        return output?
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []
    }

    private func status(at path: URL) -> ParsedGitStatus {
        let output = try? runner.runSuccessful(
            "/usr/bin/git",
            arguments: ["status", "--porcelain=v1", "--branch"],
            currentDirectory: path
        )
        return parseStatus(output ?? "")
    }

    private func lastCommitDate(at path: URL) -> Date? {
        let output = try? runner.runSuccessful(
            "/usr/bin/git",
            arguments: ["log", "-1", "--format=%ct"],
            currentDirectory: path
        )
        guard let value = output?.trimmingCharacters(in: .whitespacesAndNewlines),
              let timestamp = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func copyEnvironmentFiles(from source: URL, to destination: URL) -> [String] {
        let names = [
            ".env", ".env.local", ".env.development", ".env.development.local"
        ]
        var copied: [String] = []
        for name in names {
            let sourceFile = source.appendingPathComponent(name)
            let destinationFile = destination.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: sourceFile.path),
                  !fileManager.fileExists(atPath: destinationFile.path),
                  (try? fileManager.copyItem(at: sourceFile, to: destinationFile)) != nil else {
                continue
            }
            copied.append(name)
        }
        return copied
    }

    private static func counter(named name: String, in header: String) -> Int {
        let pattern = "\\b\(name) (\\d+)\\b"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: header,
                range: NSRange(header.startIndex..., in: header)
              ),
              let range = Range(match.range(at: 1), in: header) else { return 0 }
        return Int(header[range]) ?? 0
    }

    private static func upstream(in header: String) -> String? {
        guard let separator = header.range(of: "...") else { return nil }
        let tail = header[separator.upperBound...]
        let end = tail.range(of: " [")?.lowerBound ?? tail.endIndex
        let value = String(tail[..<end])
        return value.isEmpty ? nil : value
    }
}
