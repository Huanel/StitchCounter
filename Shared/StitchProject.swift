import Foundation

struct StitchProject: Identifiable, Codable, Equatable {
    static let defaultRowCounterName = "Vueltas"
    static let defaultStitchCounterName = "Puntos"

    let id: UUID
    var name: String
    var stitchCount: Int
    var rowCount: Int
    var stitchCounterName: String
    var rowCounterName: String

    /// Momento de la última edición. Es lo que decide quién gana cuando el
    /// reloj y el teléfono editaron el mismo proyecto sin verse.
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case stitchCount
        case rowCount
        case stitchCounterName
        case rowCounterName
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        stitchCount: Int = 0,
        rowCount: Int = 0,
        stitchCounterName: String = StitchProject.defaultStitchCounterName,
        rowCounterName: String = StitchProject.defaultRowCounterName,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.stitchCount = stitchCount
        self.rowCount = rowCount
        self.stitchCounterName = stitchCounterName
        self.rowCounterName = rowCounterName
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        stitchCount = try container.decode(Int.self, forKey: .stitchCount)
        rowCount = try container.decode(Int.self, forKey: .rowCount)
        stitchCounterName = try container.decodeIfPresent(
            String.self,
            forKey: .stitchCounterName
        ) ?? StitchProject.defaultStitchCounterName
        rowCounterName = try container.decodeIfPresent(
            String.self,
            forKey: .rowCounterName
        ) ?? StitchProject.defaultRowCounterName

        // Los proyectos guardados antes de la sincronización no tienen fecha.
        // Se tratan como los más viejos posibles: la primera edición real,
        // venga de donde venga, los pisa.
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? .distantPast
    }

    /// Compara lo que el usuario ve, ignorando la fecha de edición. Sirve para
    /// saber si dos versiones del mismo proyecto difieren de verdad.
    func hasSameContent(as other: StitchProject) -> Bool {
        id == other.id
            && name == other.name
            && stitchCount == other.stitchCount
            && rowCount == other.rowCount
            && stitchCounterName == other.stitchCounterName
            && rowCounterName == other.rowCounterName
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Proyecto sin nombre" : trimmedName
    }

    var displayStitchCounterName: String {
        displayCounterName(
            stitchCounterName,
            defaultName: StitchProject.defaultStitchCounterName
        )
    }

    var displayRowCounterName: String {
        displayCounterName(
            rowCounterName,
            defaultName: StitchProject.defaultRowCounterName
        )
    }

    private func displayCounterName(_ name: String, defaultName: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? defaultName : trimmedName
    }
}
