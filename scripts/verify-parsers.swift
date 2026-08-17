import Foundation

struct VerificationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
enum TwigDockVerification {
    static func main() throws {
        var checks = 0

        func expect<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
            checks += 1
            guard actual == expected else {
                throw VerificationFailure(
                    message: "\(name) 失败\n期望：\(expected)\n实际：\(actual)"
                )
            }
        }

        try expect(
            ScanRootConfiguration.configuredURL(from: nil)?.path,
            nil,
            "未配置时不生成扫描目录"
        )
        try expect(
            ScanRootConfiguration.configuredURL(from: "Code/workforce")?.path,
            nil,
            "相对路径不作为扫描目录"
        )
        try expect(
            ScanRootConfiguration.configuredURL(from: "/Users/me/Code/../Projects")?.path,
            "/Users/me/Projects",
            "显式扫描目录标准化"
        )

        let portService = PortService()
        let listeners = portService.parseLsof(
            """
            p301
            cnode
            f19
            PTCP
            n127.0.0.1:5173
            f20
            PTCP
            n[::1]:3000
            p77
            cmDNSResponder
            f5
            PUDP
            n*:5353
            f6
            PUDP
            n10.0.0.2:5353->224.0.0.251:5353
            """,
            protocolHint: "TCP"
        )
        try expect(listeners.count, 3, "lsof 监听记录数量")
        try expect(listeners.map(\.port), [5173, 3000, 5353], "lsof 端口解析")
        try expect(PortService.port(from: "[::1]:8080"), 8080, "IPv6 端口解析")
        try expect(PortService.port(from: "*:3000 (LISTEN)"), 3000, "LISTEN 后缀解析")
        try expect(PortService.port(from: "*:*") as Int?, nil, "非数字端口过滤")

        let metadata = portService.parseProcessMetadata(
            "  101  01:03:20 node /Users/me/app/server.js --port 3000\n"
        )
        try expect(metadata[101]?.elapsed, "01:03:20", "进程运行时间解析")
        try expect(
            metadata[101]?.command,
            "node /Users/me/app/server.js --port 3000",
            "带空格命令解析"
        )

        let gitService = GitWorktreeService()
        let worktrees = gitService.parseWorktreeList(
            """
            worktree /Users/me/Code/alpha
            HEAD d12f00d
            branch refs/heads/main

            worktree /Users/me/Code/alpha-feature
            HEAD a11ce00
            branch refs/heads/feature/login
            locked in-use

            worktree /Users/me/Code/missing
            HEAD b00b135
            detached
            prunable gitdir file points to non-existent location

            """
        )
        try expect(worktrees.count, 3, "worktree 记录数量")
        try expect(worktrees[1].branch, "feature/login", "worktree 分支解析")
        try expect(worktrees[1].isLocked, true, "worktree 锁定状态")
        try expect(worktrees[2].isDetached, true, "detached 状态")
        try expect(worktrees[2].isPrunable, true, "prunable 状态")

        let status = gitService.parseStatus(
            """
            ## feature/login...origin/feature/login [ahead 2, behind 3]
             M Sources/App.swift
            ?? Notes.md
            """
        )
        try expect(status.changeCount, 2, "改动数量")
        try expect(status.aheadCount, 2, "ahead 数量")
        try expect(status.behindCount, 3, "behind 数量")
        try expect(status.upstream, "origin/feature/login", "上游分支")

        var preferences = RepositoryPresentationPreferences(order: ["b", "a"])
        preferences.reconcile(availableIDs: ["a", "b", "c"])
        try expect(preferences.order, ["b", "a", "c"], "仓库顺序合并")
        preferences.moveToTop("c", availableIDs: ["a", "b", "c"])
        try expect(preferences.order, ["c", "b", "a"], "仓库置顶")
        preferences.move("c", offset: 1, availableIDs: ["a", "b", "c"])
        try expect(preferences.order, ["b", "c", "a"], "仓库下移")
        preferences.setAlias("  日常考勤  ", for: "attendance")
        try expect(
            preferences.displayName(
                canonicalName: "attendance",
                repositoryID: "attendance"
            ),
            "attendance（日常考勤）",
            "仓库额外显示名"
        )
        let preferenceData = try JSONEncoder().encode(preferences)
        try expect(
            try JSONDecoder().decode(
                RepositoryPresentationPreferences.self,
                from: preferenceData
            ),
            preferences,
            "仓库偏好持久化"
        )

        func worktree(
            id: String,
            repositoryID: String,
            isMain: Bool
        ) -> WorktreeRecord {
            WorktreeRecord(
                id: id,
                repositoryID: repositoryID,
                repositoryName: repositoryID,
                repositoryPath: URL(fileURLWithPath: "/tmp/\(repositoryID)"),
                branch: isMain ? "main" : "feature/\(repositoryID)",
                path: URL(fileURLWithPath: "/tmp/\(id)"),
                isMain: isMain,
                isLocked: false,
                isPrunable: false,
                changeCount: 0,
                aheadCount: 0,
                behindCount: 0,
                upstream: nil,
                lastCommitDate: nil
            )
        }

        func port(id: String, number: Int, worktreeID: String?) -> PortRecord {
            PortRecord(
                id: id,
                port: number,
                processName: "node",
                pid: 101,
                protocolName: "TCP",
                localAddress: "*:\(number)",
                state: "监听中",
                runtime: "Node.js",
                command: "node server.js",
                elapsed: "00:10",
                currentDirectory: nil,
                projectName: worktreeID == nil ? nil : "project",
                worktreeID: worktreeID
            )
        }

        let menuWorktrees = [
            worktree(id: "main-a", repositoryID: "a", isMain: true),
            worktree(id: "extra-a", repositoryID: "a", isMain: false),
            worktree(id: "main-b", repositoryID: "b", isMain: true),
            worktree(id: "extra-b", repositoryID: "b", isMain: false)
        ]
        let menuSnapshot = MenuBarContentSnapshot(
            ports: [
                port(id: "system", number: 5353, worktreeID: nil),
                port(id: "a-main", number: 3000, worktreeID: "main-a"),
                port(id: "b-extra", number: 8000, worktreeID: "extra-b"),
                port(id: "b-main", number: 7000, worktreeID: "main-b")
            ],
            worktrees: menuWorktrees,
            orderedRepositoryIDs: ["b", "a"]
        )
        try expect(
            menuSnapshot.projectPorts.map(\.id),
            ["b-main", "b-extra", "a-main"],
            "菜单栏只保留项目端口并遵循仓库顺序"
        )
        try expect(
            menuSnapshot.additionalWorktrees.map(\.id),
            ["extra-b", "extra-a"],
            "菜单栏排除主工作树并遵循仓库顺序"
        )

        print("TwigDock parser verification passed (\(checks) checks).")
    }
}
