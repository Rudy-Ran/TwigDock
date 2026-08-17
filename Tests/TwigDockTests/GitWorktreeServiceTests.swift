import XCTest
@testable import TwigDock

final class GitWorktreeServiceTests: XCTestCase {
    private let service = GitWorktreeService()

    func testParsesPorcelainWorktreeList() {
        let output = """
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

        XCTAssertEqual(
            service.parseWorktreeList(output),
            [
                ParsedWorktree(
                    path: "/Users/me/Code/alpha",
                    branch: "main",
                    isBare: false,
                    isDetached: false,
                    isLocked: false,
                    isPrunable: false
                ),
                ParsedWorktree(
                    path: "/Users/me/Code/alpha-feature",
                    branch: "feature/login",
                    isBare: false,
                    isDetached: false,
                    isLocked: true,
                    isPrunable: false
                ),
                ParsedWorktree(
                    path: "/Users/me/Code/missing",
                    branch: "游离 HEAD",
                    isBare: false,
                    isDetached: true,
                    isLocked: false,
                    isPrunable: true
                )
            ]
        )
    }

    func testParsesDirtyStatusAndSyncCounters() {
        let output = """
        ## feature/login...origin/feature/login [ahead 2, behind 3]
         M Sources/App.swift
        ?? Notes.md
        """

        XCTAssertEqual(
            service.parseStatus(output),
            ParsedGitStatus(
                changeCount: 2,
                aheadCount: 2,
                behindCount: 3,
                upstream: "origin/feature/login"
            )
        )
    }

    func testCleanStatusWithoutUpstream() {
        XCTAssertEqual(
            service.parseStatus("## main\n"),
            ParsedGitStatus(changeCount: 0, aheadCount: 0, behindCount: 0, upstream: nil)
        )
    }
}
