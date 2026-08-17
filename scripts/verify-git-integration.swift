import Foundation

struct IntegrationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
enum GitIntegrationVerification {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("TwigDockIntegration-\(UUID().uuidString)", isDirectory: true)
        let repositoryPath = root.appendingPathComponent("sample", isDirectory: true)
        let worktreePath = root.appendingPathComponent("sample-feature", isDirectory: true)
        let runner = CommandRunner()
        let service = GitWorktreeService()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            if root.lastPathComponent.hasPrefix("TwigDockIntegration-") {
                try? fileManager.removeItem(at: root)
            }
        }

        func runGit(_ arguments: [String], at directory: URL? = nil) throws -> String {
            try runner.runSuccessful(
                "/usr/bin/git",
                arguments: arguments,
                currentDirectory: directory
            )
        }

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw IntegrationFailure(message: message) }
        }

        _ = try runGit(["init", "-b", "main", repositoryPath.path])
        _ = try runGit(["config", "user.name", "TwigDock Verification"], at: repositoryPath)
        _ = try runGit(["config", "user.email", "verification@twigdock.local"], at: repositoryPath)
        try "# Sample\n".write(
            to: repositoryPath.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try "LOCAL_ONLY=true\n".write(
            to: repositoryPath.appendingPathComponent(".env"),
            atomically: true,
            encoding: .utf8
        )
        try ".env\n".write(
            to: repositoryPath.appendingPathComponent(".gitignore"),
            atomically: true,
            encoding: .utf8
        )
        _ = try runGit(["add", "README.md", ".gitignore"], at: repositoryPath)
        _ = try runGit(["commit", "-m", "Initial commit"], at: repositoryPath)

        let initial = try service.scan(root: root, maximumDepth: 2)
        try expect(initial.repositories.count == 1, "初始仓库发现失败")
        try expect(initial.worktrees.filter { !$0.isMain }.isEmpty, "主目录不应算作附加工作树")
        guard let repository = initial.repositories.first else {
            throw IntegrationFailure(message: "没有解析到测试仓库")
        }

        let copied = try service.createWorktree(
            WorktreeCreationRequest(
                repository: repository,
                baseBranch: "main",
                newBranch: "test/integration",
                destination: worktreePath,
                copyEnvironmentFiles: true
            )
        )
        try expect(copied == [".env"], "环境文件复制结果不正确")
        try expect(
            fileManager.fileExists(atPath: worktreePath.appendingPathComponent(".env").path),
            "环境文件没有复制到新工作树"
        )

        try "uncommitted\n".write(
            to: worktreePath.appendingPathComponent("scratch.txt"),
            atomically: true,
            encoding: .utf8
        )
        let created = try service.scan(root: root, maximumDepth: 2)
        let additional = created.worktrees.filter { !$0.isMain }
        try expect(additional.count == 1, "新建后附加工作树数量不正确")
        guard let worktree = additional.first else {
            throw IntegrationFailure(message: "没有解析到新建工作树")
        }
        try expect(worktree.branch == "test/integration", "新建工作树分支不正确")
        try expect(worktree.changeCount == 1, "未提交文件没有被识别")

        try service.removeWorktree(
            WorktreeRemovalRequest(
                worktree: worktree,
                force: true,
                stopLinkedProcesses: false,
                deleteBranch: true
            )
        )
        try expect(!fileManager.fileExists(atPath: worktreePath.path), "工作树目录没有移除")
        let branch = try runGit(["branch", "--list", "test/integration"], at: repositoryPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try expect(branch.isEmpty, "本地分支没有删除")

        let final = try service.scan(root: root, maximumDepth: 2)
        try expect(final.worktrees.filter { !$0.isMain }.isEmpty, "移除后仍残留附加工作树")
        print("TwigDock Git integration verification passed.")
    }
}
