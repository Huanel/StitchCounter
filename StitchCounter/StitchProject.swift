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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case stitchCount
        case rowCount
        case stitchCounterName
        case rowCounterName
    }

    init(
        id: UUID = UUID(),
        name: String,
        stitchCount: Int = 0,
        rowCount: Int = 0,
        stitchCounterName: String = StitchProject.defaultStitchCounterName,
        rowCounterName: String = StitchProject.defaultRowCounterName
    ) {
        self.id = id
        self.name = name
        self.stitchCount = stitchCount
        self.rowCount = rowCount
        self.stitchCounterName = stitchCounterName
        self.rowCounterName = rowCounterName
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
