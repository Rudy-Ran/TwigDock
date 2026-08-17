import XCTest
@testable import TwigDock

final class RepositoryPresentationPreferencesTests: XCTestCase {
    func testScanRootRequiresAnExplicitAbsolutePath() {
        XCTAssertNil(ScanRootConfiguration.configuredURL(from: nil))
        XCTAssertNil(ScanRootConfiguration.configuredURL(from: "  "))
        XCTAssertNil(ScanRootConfiguration.configuredURL(from: "Code/workforce"))
        XCTAssertEqual(
            ScanRootConfiguration.configuredURL(from: "/Users/me/Code/../Projects")?.path,
            "/Users/me/Projects"
        )
    }

    func testReconcilesMovesAndKeepsNewRepositories() {
        var preferences = RepositoryPresentationPreferences(order: ["b", "a"])
        preferences.reconcile(availableIDs: ["a", "b", "c"])
        XCTAssertEqual(preferences.order, ["b", "a", "c"])

        preferences.moveToTop("c", availableIDs: ["a", "b", "c"])
        XCTAssertEqual(preferences.order, ["c", "b", "a"])

        preferences.move("c", offset: 1, availableIDs: ["a", "b", "c"])
        XCTAssertEqual(preferences.order, ["b", "c", "a"])
    }

    func testAliasIsTrimmedAndCanBeCleared() {
        var preferences = RepositoryPresentationPreferences()
        preferences.setAlias("  日常考勤  ", for: "attendance")
        XCTAssertEqual(
            preferences.displayName(canonicalName: "attendance", repositoryID: "attendance"),
            "attendance（日常考勤）"
        )

        preferences.setAlias("  ", for: "attendance")
        XCTAssertEqual(
            preferences.displayName(canonicalName: "attendance", repositoryID: "attendance"),
            "attendance"
        )
    }

    func testPreferencesRoundTripThroughJSON() throws {
        let original = RepositoryPresentationPreferences(
            order: ["workforce", "attendance"],
            aliases: ["attendance": "日常考勤"]
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(
            try JSONDecoder().decode(RepositoryPresentationPreferences.self, from: data),
            original
        )
    }
}
