//
//  StitchCounterTests.swift
//  StitchCounterTests
//
//  Created by Marcia Orezzoli on 23/06/2026.
//

import XCTest
@testable import StitchCounter

final class StitchCounterTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "ProjectStoreTests-\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
    }

    func testProjectStorePersistsEachProjectCounter() throws {
        let store = ProjectStore(userDefaults: userDefaults)

        let sweater = store.addProject(name: "Sweater")
        let scarf = store.addProject(name: "Bufanda")

        store.updateCounts(for: sweater.id, stitchCount: 24, rowCount: 8)
        store.updateCounts(for: scarf.id, stitchCount: 12, rowCount: 3)

        let reloadedStore = ProjectStore(userDefaults: userDefaults)

        XCTAssertEqual(reloadedStore.projects.count, 2)
        XCTAssertEqual(reloadedStore.project(id: sweater.id)?.name, "Sweater")
        XCTAssertEqual(reloadedStore.project(id: sweater.id)?.stitchCount, 24)
        XCTAssertEqual(reloadedStore.project(id: sweater.id)?.rowCount, 8)
        XCTAssertEqual(reloadedStore.project(id: sweater.id)?.displayStitchCounterName, "Puntos")
        XCTAssertEqual(reloadedStore.project(id: sweater.id)?.displayRowCounterName, "Vueltas")
        XCTAssertEqual(reloadedStore.project(id: scarf.id)?.name, "Bufanda")
        XCTAssertEqual(reloadedStore.project(id: scarf.id)?.stitchCount, 12)
        XCTAssertEqual(reloadedStore.project(id: scarf.id)?.rowCount, 3)
    }

    func testProjectStoreDoesNotAllowNegativeCounters() throws {
        let store = ProjectStore(userDefaults: userDefaults)
        let project = store.addProject()

        store.adjustRowCount(for: project.id, by: -1)
        store.adjustStitchCount(for: project.id, by: -1)

        XCTAssertEqual(store.project(id: project.id)?.rowCount, 0)
        XCTAssertEqual(store.project(id: project.id)?.stitchCount, 0)
    }

    func testProjectStoreMigratesLegacyCounterValues() throws {
        userDefaults.set(7, forKey: "rowCount")
        userDefaults.set(31, forKey: "stitchCount")

        let store = ProjectStore(userDefaults: userDefaults)

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.projects.first?.name, "Mi proyecto")
        XCTAssertEqual(store.projects.first?.rowCount, 7)
        XCTAssertEqual(store.projects.first?.stitchCount, 31)
    }

    func testProjectStorePersistsCounterNames() throws {
        let store = ProjectStore(userDefaults: userDefaults)
        let project = store.addProject()

        store.updateRowCounterName(for: project.id, name: "Rondas")
        store.updateStitchCounterName(for: project.id, name: "Aumentos")

        let reloadedStore = ProjectStore(userDefaults: userDefaults)

        XCTAssertEqual(reloadedStore.project(id: project.id)?.displayRowCounterName, "Rondas")
        XCTAssertEqual(reloadedStore.project(id: project.id)?.displayStitchCounterName, "Aumentos")
    }

    func testProjectDecodesStoredProjectsWithoutCounterNames() throws {
        let id = UUID()
        let legacyJSON = """
        [
          {
            "id": "\(id.uuidString)",
            "name": "Proyecto viejo",
            "stitchCount": 9,
            "rowCount": 4
          }
        ]
        """

        userDefaults.set(Data(legacyJSON.utf8), forKey: "stitchProjects")

        let store = ProjectStore(userDefaults: userDefaults)

        XCTAssertEqual(store.project(id: id)?.displayRowCounterName, "Vueltas")
        XCTAssertEqual(store.project(id: id)?.displayStitchCounterName, "Puntos")
    }
}
