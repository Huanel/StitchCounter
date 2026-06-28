import Combine
import Foundation

final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [StitchProject]

    private let userDefaults: UserDefaults
    private let storageKey = "stitchProjects"
    private let legacyRowCountKey = "rowCount"
    private let legacyStitchCountKey = "stitchCount"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.projects = []
        self.projects = loadProjects()
    }

    @discardableResult
    func addProject(name: String = "Nuevo proyecto") -> StitchProject {
        let project = StitchProject(name: name)
        var updatedProjects = projects
        updatedProjects.append(project)
        setProjects(updatedProjects)
        return project
    }

    func deleteProject(id: StitchProject.ID) {
        let updatedProjects = projects.filter { $0.id != id }
        setProjects(updatedProjects)
    }

    func updateName(for id: StitchProject.ID, name: String) {
        updateProject(id: id) { project in
            project.name = name
        }
    }

    func updateStitchCounterName(for id: StitchProject.ID, name: String) {
        updateProject(id: id) { project in
            project.stitchCounterName = name
        }
    }

    func updateRowCounterName(for id: StitchProject.ID, name: String) {
        updateProject(id: id) { project in
            project.rowCounterName = name
        }
    }

    func updateCounts(
        for id: StitchProject.ID,
        stitchCount: Int,
        rowCount: Int
    ) {
        updateProject(id: id) { project in
            project.stitchCount = max(0, stitchCount)
            project.rowCount = max(0, rowCount)
        }
    }

    func updateStitchCount(for id: StitchProject.ID, stitchCount: Int) {
        updateProject(id: id) { project in
            project.stitchCount = max(0, stitchCount)
        }
    }

    func updateRowCount(for id: StitchProject.ID, rowCount: Int) {
        updateProject(id: id) { project in
            project.rowCount = max(0, rowCount)
        }
    }

    func adjustStitchCount(for id: StitchProject.ID, by amount: Int) {
        guard let project = project(id: id) else { return }
        updateStitchCount(for: id, stitchCount: project.stitchCount + amount)
    }

    func adjustRowCount(for id: StitchProject.ID, by amount: Int) {
        guard let project = project(id: id) else { return }
        updateRowCount(for: id, rowCount: project.rowCount + amount)
    }

    func project(id: StitchProject.ID) -> StitchProject? {
        projects.first { $0.id == id }
    }

    private func updateProject(
        id: StitchProject.ID,
        update: (inout StitchProject) -> Void
    ) {
        var updatedProjects = projects
        guard let index = updatedProjects.firstIndex(where: { $0.id == id }) else {
            return
        }

        update(&updatedProjects[index])
        setProjects(updatedProjects)
    }

    private func setProjects(_ projects: [StitchProject]) {
        self.projects = projects
        saveProjects()
    }

    private func loadProjects() -> [StitchProject] {
        if let data = userDefaults.data(forKey: storageKey),
           let projects = try? JSONDecoder().decode([StitchProject].self, from: data) {
            return projects
        }

        let migratedProjects = migrateLegacyCounterIfNeeded()
        if !migratedProjects.isEmpty {
            saveProjects(migratedProjects)
        }
        return migratedProjects
    }

    private func migrateLegacyCounterIfNeeded() -> [StitchProject] {
        let hasLegacyRows = userDefaults.object(forKey: legacyRowCountKey) != nil
        let hasLegacyStitches = userDefaults.object(forKey: legacyStitchCountKey) != nil

        guard hasLegacyRows || hasLegacyStitches else {
            return []
        }

        return [
            StitchProject(
                name: "Mi proyecto",
                stitchCount: userDefaults.integer(forKey: legacyStitchCountKey),
                rowCount: userDefaults.integer(forKey: legacyRowCountKey)
            )
        ]
    }

    private func saveProjects() {
        saveProjects(projects)
    }

    private func saveProjects(_ projects: [StitchProject]) {
        guard let data = try? JSONEncoder().encode(projects) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
