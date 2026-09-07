import Foundation

/// Marca de que un proyecto fue borrado. Sin esto, borrar en el teléfono y
/// después sincronizar con el reloj resucitaría el proyecto, porque el reloj
/// todavía lo tiene y no hay forma de distinguir "borrado" de "todavía no llegó".
struct ProjectTombstone: Identifiable, Codable, Equatable {
    let id: UUID
    let deletedAt: Date
}

/// Todo lo que un lado le manda al otro: los proyectos vivos y los borrados.
struct ProjectSnapshot: Codable, Equatable {
    var projects: [StitchProject]
    var tombstones: [ProjectTombstone]

    init(projects: [StitchProject] = [], tombstones: [ProjectTombstone] = []) {
        self.projects = projects
        self.tombstones = tombstones
    }

    static let empty = ProjectSnapshot()
}

enum ProjectMerge {
    /// Cuánto se recuerda un borrado. Pasado ese plazo se olvida: si un reloj
    /// estuvo apagado más de un mes, el proyecto vuelve. Es preferible a
    /// acumular lápidas para siempre.
    static let tombstoneLifetime: TimeInterval = 60 * 60 * 24 * 30

    /// Fusiona dos estados sin depender de quién es "el principal". Es
    /// conmutativa salvo por el orden de la lista y por los empates exactos de
    /// fecha, que se resuelven a favor de `local`.
    ///
    /// Reglas, en orden:
    /// 1. Un proyecto editado en los dos lados: gana el `updatedAt` más nuevo.
    /// 2. Un borrado gana sobre una edición anterior a él.
    /// 3. Una edición posterior al borrado gana sobre el borrado (lo revive y
    ///    descarta la lápida): si seguiste tejiendo en el reloj después de
    ///    borrarlo en el teléfono, mandan los puntos.
    /// 4. El orden de la lista local se preserva; lo que solo existe del otro
    ///    lado se agrega al final.
    static func merge(
        local: ProjectSnapshot,
        remote: ProjectSnapshot,
        now: Date = Date()
    ) -> ProjectSnapshot {
        var deletions: [UUID: Date] = [:]
        for tombstone in local.tombstones + remote.tombstones {
            if let existing = deletions[tombstone.id], existing >= tombstone.deletedAt {
                continue
            }
            deletions[tombstone.id] = tombstone.deletedAt
        }

        var winners: [UUID: StitchProject] = [:]
        for project in remote.projects {
            winners[project.id] = project
        }
        for project in local.projects {
            if let rival = winners[project.id], rival.updatedAt > project.updatedAt {
                continue
            }
            winners[project.id] = project
        }

        // Una edición posterior al borrado revive el proyecto y anula la lápida.
        for (id, project) in winners where deletions[id] != nil {
            if project.updatedAt > deletions[id]! {
                deletions.removeValue(forKey: id)
            } else {
                winners.removeValue(forKey: id)
            }
        }

        var ordered: [StitchProject] = []
        var placed = Set<UUID>()
        for project in local.projects {
            if let winner = winners[project.id] {
                ordered.append(winner)
                placed.insert(project.id)
            }
        }
        for project in remote.projects where !placed.contains(project.id) {
            if let winner = winners[project.id] {
                ordered.append(winner)
                placed.insert(project.id)
            }
        }

        let survivingTombstones = deletions
            .filter { now.timeIntervalSince($0.value) < tombstoneLifetime }
            .map { ProjectTombstone(id: $0.key, deletedAt: $0.value) }
            .sorted { $0.deletedAt < $1.deletedAt }

        return ProjectSnapshot(projects: ordered, tombstones: survivingTombstones)
    }
}
