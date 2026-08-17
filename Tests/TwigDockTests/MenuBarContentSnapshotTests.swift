import Foundation
import XCTest
@testable import TwigDock

final class MenuBarContentSnapshotTests: XCTestCase {
    func testKeepsOnlyProjectPortsAndAdditionalWorktreesInRepositoryOrder() {
        let worktrees = [
            worktree(id: "main-a", repositoryID: "a", isMain: true),
            worktree(id: "extra-a", repositoryID: "a", isMain: false),
            worktree(id: "main-b", repositoryID: "b", isMain: true),
            worktree(id: "extra-b", repositoryID: "b", isMain: false)
        ]
        let ports = [
            port(id: "system", number: 5353, worktreeID: nil),
            port(id: "a-main", number: 3000, worktreeID: "main-a"),
            port(id: "b-extra", number: 8000, worktreeID: "extra-b"),
            port(id: "b-main", number: 7000, worktreeID: "main-b")
        ]

        let snapshot = MenuBarContentSnapshot(
            ports: ports,
            worktrees: worktrees,
            orderedRepositoryIDs: ["b", "a"]
        )

        XCTAssertEqual(snapshot.projectPorts.map(\.id), ["b-main", "b-extra", "a-main"])
        XCTAssertEqual(snapshot.additionalWorktrees.map(\.id), ["extra-b", "extra-a"])
    }

    private func port(id: String, number: Int, worktreeID: String?) -> PortRecord {
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

    private func worktree(
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
}
