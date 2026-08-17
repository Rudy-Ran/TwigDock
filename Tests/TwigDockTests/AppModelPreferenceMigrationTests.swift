import Foundation
import XCTest
@testable import TwigDock

@MainActor
final class AppModelPreferenceMigrationTests: XCTestCase {
    func testMigratesLegacyScanRootAndRepositoryPreferences() throws {
        let currentSuiteName = "dev.twigdock.tests.current.\(UUID().uuidString)"
        let legacySuiteName = "dev.twigdock.tests.legacy.\(UUID().uuidString)"
        let currentDefaults = try XCTUnwrap(UserDefaults(suiteName: currentSuiteName))
        let legacyDefaults = try XCTUnwrap(UserDefaults(suiteName: legacySuiteName))
        defer {
            currentDefaults.removePersistentDomain(forName: currentSuiteName)
            legacyDefaults.removePersistentDomain(forName: legacySuiteName)
        }

        let root = FileManager.default.temporaryDirectory.standardizedFileURL
        let preferences = RepositoryPresentationPreferences(
            order: ["/tmp/repository/.git"],
            aliases: ["/tmp/repository/.git": "示例仓库"]
        )
        legacyDefaults.set(root.path, forKey: "BranchPort.scanRoot")
        legacyDefaults.set(
            try JSONEncoder().encode(preferences),
            forKey: "BranchPort.repositoryPreferences"
        )

        let model = AppModel(defaults: currentDefaults, legacyDefaults: legacyDefaults)

        XCTAssertEqual(model.scanRoot, root)
        XCTAssertEqual(model.repositoryPreferences, preferences)
        XCTAssertEqual(currentDefaults.string(forKey: "TwigDock.scanRoot"), root.path)
        XCTAssertNotNil(currentDefaults.data(forKey: "TwigDock.repositoryPreferences"))
    }

    func testCurrentPreferencesTakePrecedenceOverLegacyValues() throws {
        let currentSuiteName = "dev.twigdock.tests.current.\(UUID().uuidString)"
        let legacySuiteName = "dev.twigdock.tests.legacy.\(UUID().uuidString)"
        let currentDefaults = try XCTUnwrap(UserDefaults(suiteName: currentSuiteName))
        let legacyDefaults = try XCTUnwrap(UserDefaults(suiteName: legacySuiteName))
        defer {
            currentDefaults.removePersistentDomain(forName: currentSuiteName)
            legacyDefaults.removePersistentDomain(forName: legacySuiteName)
        }

        let currentRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        let legacyRoot = currentRoot.appendingPathComponent("legacy", isDirectory: true)
        currentDefaults.set(currentRoot.path, forKey: "TwigDock.scanRoot")
        legacyDefaults.set(legacyRoot.path, forKey: "BranchPort.scanRoot")

        let model = AppModel(defaults: currentDefaults, legacyDefaults: legacyDefaults)

        XCTAssertEqual(model.scanRoot, currentRoot)
    }
}
