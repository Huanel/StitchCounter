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

    /// Los tests no hablan con el reloj: `syncService: nil` deja el store puro.
    private func makeStore() -> ProjectStore {
        ProjectStore(userDefaults: userDefaults, syncService: nil)
    }

    // MARK: - Persistencia

    func testProjectStorePersistsEachProjectCounter() throws {
        let store = makeStore()

        let sweater = store.addProject(name: "Sweater")
        let scarf = store.addProject(name: "Bufanda")

        store.updateCounts(for: sweater.id, stitchCount: 24, rowCount: 8)
        store.updateCounts(for: scarf.id, stitchCount: 12, rowCount: 3)

        let reloadedStore = makeStore()

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
        let store = makeStore()
        let project = store.addProject()

        store.adjustRowCount(for: project.id, by: -1)
        store.adjustStitchCount(for: project.id, by: -1)

        XCTAssertEqual(store.project(id: project.id)?.rowCount, 0)
        XCTAssertEqual(store.project(id: project.id)?.stitchCount, 0)
    }

    func testProjectStoreMigratesLegacyCounterValues() throws {
        userDefaults.set(7, forKey: "rowCount")
        userDefaults.set(31, forKey: "stitchCount")

        let store = makeStore()

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.projects.first?.name, "Mi proyecto")
        XCTAssertEqual(store.projects.first?.rowCount, 7)
        XCTAssertEqual(store.projects.first?.stitchCount, 31)
    }

    func testProjectStorePersistsCounterNames() throws {
        let store = makeStore()
        let project = store.addProject()

        store.updateRowCounterName(for: project.id, name: "Rondas")
        store.updateStitchCounterName(for: project.id, name: "Aumentos")

        let reloadedStore = makeStore()

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

        let store = makeStore()

        XCTAssertEqual(store.project(id: id)?.displayRowCounterName, "Vueltas")
        XCTAssertEqual(store.project(id: id)?.displayStitchCounterName, "Puntos")
    }

    func testProjectWithoutStoredDateIsTreatedAsOldest() throws {
        let id = UUID()
        let legacyJSON = """
        [{"id":"\(id.uuidString)","name":"Viejo","stitchCount":1,"rowCount":1}]
        """
        userDefaults.set(Data(legacyJSON.utf8), forKey: "stitchProjects")

        let store = makeStore()

        XCTAssertEqual(store.project(id: id)?.updatedAt, .distantPast)
    }

    // MARK: - Fusión entre reloj y teléfono

    func testMergeKeepsMostRecentEditOfTheSameProject() throws {
        let id = UUID()
        let older = StitchProject(
            id: id, name: "Bufanda", stitchCount: 5, rowCount: 1,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = StitchProject(
            id: id, name: "Bufanda", stitchCount: 40, rowCount: 9,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let merged = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [older]),
            remote: ProjectSnapshot(projects: [newer])
        )

        XCTAssertEqual(merged.projects.count, 1)
        XCTAssertEqual(merged.projects.first?.stitchCount, 40)
        XCTAssertEqual(merged.projects.first?.rowCount, 9)
    }

    func testMergeIsSymmetricRegardlessOfWhichSideIsLocal() throws {
        let id = UUID()
        let older = StitchProject(id: id, name: "A", stitchCount: 5, updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = StitchProject(id: id, name: "A", stitchCount: 40, updatedAt: Date(timeIntervalSince1970: 2_000))

        let oneWay = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [older]),
            remote: ProjectSnapshot(projects: [newer])
        )
        let otherWay = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [newer]),
            remote: ProjectSnapshot(projects: [older])
        )

        XCTAssertEqual(oneWay.projects, otherWay.projects)
    }

    func testMergeKeepsProjectsThatOnlyExistOnOneSide() throws {
        let mine = StitchProject(name: "Solo en el teléfono")
        let theirs = StitchProject(name: "Solo en el reloj")

        let merged = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [mine]),
            remote: ProjectSnapshot(projects: [theirs])
        )

        XCTAssertEqual(merged.projects.count, 2)
        XCTAssertEqual(merged.projects.first?.id, mine.id, "el orden local se preserva")
        XCTAssertEqual(merged.projects.last?.id, theirs.id)
    }

    func testDeletedProjectIsNotResurrectedByTheOtherDevice() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = StitchProject(
            name: "Borrado",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let tombstone = ProjectTombstone(id: project.id, deletedAt: Date(timeIntervalSince1970: 2_000))

        let merged = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [], tombstones: [tombstone]),
            remote: ProjectSnapshot(projects: [project]),
            now: now
        )

        XCTAssertTrue(merged.projects.isEmpty)
        XCTAssertEqual(merged.tombstones.count, 1, "la lápida se conserva hasta que caduque")
    }

    func testEditAfterDeletionRevivesTheProject() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = StitchProject(
            name: "Seguí tejiendo",
            stitchCount: 12,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let tombstone = ProjectTombstone(id: project.id, deletedAt: Date(timeIntervalSince1970: 2_000))

        let merged = ProjectMerge.merge(
            local: ProjectSnapshot(projects: [], tombstones: [tombstone]),
            remote: ProjectSnapshot(projects: [project]),
            now: now
        )

        XCTAssertEqual(merged.projects.count, 1)
        XCTAssertEqual(merged.projects.first?.stitchCount, 12)
        XCTAssertTrue(merged.tombstones.isEmpty, "la lápida se descarta al revivir")
    }

    func testOldTombstonesArePruned() throws {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let stale = ProjectTombstone(
            id: UUID(),
            deletedAt: now.addingTimeInterval(-ProjectMerge.tombstoneLifetime - 1)
        )
        let fresh = ProjectTombstone(id: UUID(), deletedAt: now.addingTimeInterval(-60))

        let merged = ProjectMerge.merge(
            local: ProjectSnapshot(tombstones: [stale, fresh]),
            remote: .empty,
            now: now
        )

        XCTAssertEqual(merged.tombstones.map(\.id), [fresh.id])
    }

    func testStoreAppliesRemoteSnapshot() throws {
        let store = makeStore()
        let mine = store.addProject(name: "Teléfono")
        let theirs = StitchProject(name: "Reloj", stitchCount: 7)

        store.apply(ProjectSnapshot(projects: [theirs]))

        XCTAssertEqual(store.projects.count, 2)
        XCTAssertEqual(store.project(id: theirs.id)?.stitchCount, 7)
        XCTAssertEqual(store.projects.first?.id, mine.id)

        let reloadedStore = makeStore()
        XCTAssertEqual(reloadedStore.projects.count, 2, "lo fusionado también se guarda")
    }

    // MARK: - Deshacer

    func testUndoRestoresPreviousCount() throws {
        let store = makeStore()
        let project = store.addProject(name: "Bufanda")
        store.updateRowCount(for: project.id, rowCount: 10)
        store.adjustRowCount(for: project.id, by: 1)

        XCTAssertEqual(store.project(id: project.id)?.rowCount, 11)

        store.undo()

        XCTAssertEqual(store.project(id: project.id)?.rowCount, 10)
    }

    func testUndoIsUnavailableWithNothingToUndo() throws {
        let store = makeStore()
        XCTAssertFalse(store.canUndo)

        store.addProject()
        XCTAssertTrue(store.canUndo)
    }

    func testUndoStampsRestoredValuesAsANewEdit() throws {
        let store = makeStore()
        let project = store.addProject(name: "Bufanda")
        store.updateRowCount(for: project.id, rowCount: 10)
        let beforeUndo = try XCTUnwrap(store.project(id: project.id)).updatedAt

        store.adjustRowCount(for: project.id, by: 1)
        store.undo()

        let restored = try XCTUnwrap(store.project(id: project.id))
        XCTAssertEqual(restored.rowCount, 10)
        XCTAssertGreaterThan(
            restored.updatedAt, beforeUndo,
            "sin sellar la hora, el reloj tendría una versión más nueva y desharía el deshacer"
        )
    }

    func testUndoOfADeleteBringsTheProjectBackAndDropsItsTombstone() throws {
        let store = makeStore()
        let project = store.addProject(name: "Sin querer")
        store.deleteProject(id: project.id)
        XCTAssertTrue(store.projects.isEmpty)

        store.undo()

        XCTAssertEqual(store.projects.count, 1)

        // La lápida tiene que haberse ido: si no, la fusión lo volvería a borrar.
        store.apply(ProjectSnapshot(projects: store.projects))
        XCTAssertEqual(store.projects.count, 1, "no debe volver a borrarse al sincronizar")
    }

    func testRemoteChangeClearsUndoToAvoidDiscardingIt() throws {
        let store = makeStore()
        let project = store.addProject(name: "Local")
        store.adjustRowCount(for: project.id, by: 1)
        XCTAssertTrue(store.canUndo)

        store.apply(ProjectSnapshot(projects: [StitchProject(name: "Del reloj")]))

        XCTAssertFalse(store.canUndo, "deshacer borraría el proyecto que acaba de llegar")
    }

    func testStoreRecordsTombstoneOnDeleteSoItSurvivesSync() throws {
        let store = makeStore()
        let project = store.addProject(name: "Para borrar")
        store.deleteProject(id: project.id)

        XCTAssertTrue(store.projects.isEmpty)

        // El otro dispositivo todavía lo tiene y lo manda de vuelta.
        store.apply(ProjectSnapshot(projects: [project]))

        XCTAssertTrue(store.projects.isEmpty, "no debe resucitar")
    }
}
