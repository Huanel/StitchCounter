import Combine
import Foundation

final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [StitchProject]

    /// Si hay algo para deshacer. La UI muestra el botón solo cuando es true.
    @Published private(set) var canUndo = false

    private let userDefaults: UserDefaults
    private let syncService: WatchSyncService?
    private let storageKey = "stitchProjects"
    private let tombstoneKey = "stitchTombstones"
    private let legacyRowCountKey = "rowCount"
    private let legacyStitchCountKey = "stitchCount"

    private var tombstones: [ProjectTombstone] = []
    private var pendingSync: DispatchWorkItem?
    private let syncDelay: TimeInterval = 0.4

    /// Estados anteriores, del más viejo al más nuevo. Vive solo en memoria: el
    /// deshacer sirve para el error que acabás de cometer, no entre sesiones.
    private var undoStack: [UndoEntry] = []
    private let undoLimit = 30

    private struct UndoEntry {
        let projects: [StitchProject]
        let tombstones: [ProjectTombstone]
    }

    init(
        userDefaults: UserDefaults = .standard,
        syncService: WatchSyncService? = .shared
    ) {
        self.userDefaults = userDefaults
        self.syncService = syncService
        self.projects = []
        self.tombstones = loadTombstones()
        self.projects = loadProjects()

        guard let syncService else { return }
        syncService.onReceive = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        syncService.onReady = { [weak self] in
            self?.scheduleSync()
        }
        syncService.start()
    }

    // MARK: - Estado sincronizable

    var snapshot: ProjectSnapshot {
        ProjectSnapshot(projects: projects, tombstones: tombstones)
    }

    /// Integra lo que llegó del otro dispositivo. Si la fusión cambió algo,
    /// vuelve a publicar para que los dos lados terminen iguales.
    func apply(_ remote: ProjectSnapshot) {
        let merged = ProjectMerge.merge(local: snapshot, remote: remote)
        let changedLocally = merged.projects != projects || merged.tombstones != tombstones

        if changedLocally {
            projects = merged.projects
            tombstones = merged.tombstones
            persist()

            // Los estados guardados para deshacer son anteriores a lo que acaba
            // de llegar del otro dispositivo. Restaurar uno borraría ese cambio
            // ajeno sin que nadie lo pidiera, así que el deshacer se corta acá.
            undoStack.removeAll()
            canUndo = false
        }

        // Si el otro lado tenía menos información que el resultado, hay que
        // devolvérselo. Si ya coincidían, callarse evita el ida y vuelta infinito.
        if merged.projects != remote.projects || merged.tombstones != remote.tombstones {
            scheduleSync()
        }
    }

    // MARK: - Mutaciones

    @discardableResult
    func addProject(name: String = "Nuevo proyecto") -> StitchProject {
        let project = StitchProject(name: name)
        var updatedProjects = projects
        updatedProjects.append(project)
        setProjects(updatedProjects)
        return project
    }

    func deleteProject(id: StitchProject.ID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        pushUndo()
        tombstones.append(ProjectTombstone(id: id, deletedAt: Date()))
        setProjects(projects.filter { $0.id != id }, recordUndo: false)
    }

    // MARK: - Deshacer

    /// Vuelve al estado anterior al último cambio.
    ///
    /// Restaurar valores viejos tiene un detalle propio de la sincronización: si
    /// se guardaran con su `updatedAt` original, el reloj tendría una versión
    /// "más nueva" y al sincronizar desharía el deshacer. Por eso lo restaurado
    /// se sella con la hora actual — es una edición nueva, y como tal gana.
    func undo() {
        guard let entry = undoStack.popLast() else { return }
        canUndo = !undoStack.isEmpty

        let now = Date()
        let current = Dictionary(
            projects.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var restored = entry.projects
        for index in restored.indices {
            let existing = current[restored[index].id]
            if existing == nil || !existing!.hasSameContent(as: restored[index]) {
                restored[index].updatedAt = now
            }
        }

        projects = restored
        // Recuperar un proyecto borrado exige soltar su lápida; si no, la
        // fusión con el reloj lo volvería a borrar enseguida.
        tombstones = entry.tombstones
        persist()
        scheduleSync()
    }

    private func pushUndo() {
        undoStack.append(UndoEntry(projects: projects, tombstones: tombstones))
        if undoStack.count > undoLimit {
            undoStack.removeFirst()
        }
        canUndo = true
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

        let before = updatedProjects[index]
        update(&updatedProjects[index])
        guard updatedProjects[index] != before else { return }

        updatedProjects[index].updatedAt = Date()
        setProjects(updatedProjects)
    }

    private func setProjects(_ projects: [StitchProject], recordUndo: Bool = true) {
        if recordUndo {
            pushUndo()
        }
        self.projects = projects
        persist()
        scheduleSync()
    }

    // MARK: - Sincronización

    private func scheduleSync() {
        guard let syncService, syncService.isSupported else { return }
        pendingSync?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSync = nil
            syncService.send(self.snapshot)
        }
        pendingSync = work
        DispatchQueue.main.asyncAfter(deadline: .now() + syncDelay, execute: work)
    }

    // MARK: - Persistencia

    private func loadProjects() -> [StitchProject] {
        if let data = userDefaults.data(forKey: storageKey),
           let projects = try? JSONDecoder.sync.decode([StitchProject].self, from: data) {
            return projects
        }

        let migratedProjects = migrateLegacyCounterIfNeeded()
        if !migratedProjects.isEmpty {
            saveProjects(migratedProjects)
        }
        return migratedProjects
    }

    private func loadTombstones() -> [ProjectTombstone] {
        guard let data = userDefaults.data(forKey: tombstoneKey),
              let tombstones = try? JSONDecoder.sync.decode([ProjectTombstone].self, from: data) else {
            return []
        }
        return tombstones
    }

    /// Recupera el contador único de las primeras versiones de la app — y, en el
    /// reloj, el que venía de `@AppStorage("rowCount"/"stitchCount")`.
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

    private func persist() {
        saveProjects(projects)
        saveTombstones(tombstones)
    }

    private func saveProjects(_ projects: [StitchProject]) {
        guard let data = try? JSONEncoder.sync.encode(projects) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }

    private func saveTombstones(_ tombstones: [ProjectTombstone]) {
        guard let data = try? JSONEncoder.sync.encode(tombstones) else {
            return
        }

        userDefaults.set(data, forKey: tombstoneKey)
    }
}
