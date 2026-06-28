import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var resetTarget: ResetTarget?

    let projectID: StitchProject.ID

    var body: some View {
        ZStack {
            StitchColors.background
                .ignoresSafeArea()

            if let project = store.project(id: projectID) {
                counterContent(for: project)
            } else {
                missingProjectView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $resetTarget) { target in
            let counterName = displayCounterName(for: target)
            return Alert(
                title: Text("Reiniciar \(counterName.lowercased())"),
                message: Text("¿Querés volver \(counterName.lowercased()) a cero?"),
                primaryButton: .destructive(Text("Reiniciar")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        reset(target)
                    }
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }

    private func counterContent(for project: StitchProject) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                TextField("Nombre del proyecto", text: projectName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(StitchColors.text)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityLabel("Nombre del proyecto")

                Text("Contador de puntos y vueltas")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(StitchColors.secondaryText)
            }
            .padding(.top, 18)

            VStack(spacing: 18) {
                CounterCard(
                    title: rowCounterName,
                    defaultTitle: StitchProject.defaultRowCounterName,
                    value: project.rowCount,
                    accentColor: StitchColors.dustyRose,
                    minusAction: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.adjustRowCount(for: projectID, by: -1)
                        }
                    },
                    plusAction: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.adjustRowCount(for: projectID, by: 1)
                        }
                    },
                    resetAction: {
                        resetTarget = .rows
                    }
                )

                CounterCard(
                    title: stitchCounterName,
                    defaultTitle: StitchProject.defaultStitchCounterName,
                    value: project.stitchCount,
                    accentColor: StitchColors.sage,
                    minusAction: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.adjustStitchCount(for: projectID, by: -1)
                        }
                    },
                    plusAction: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.adjustStitchCount(for: projectID, by: 1)
                        }
                    },
                    resetAction: {
                        resetTarget = .stitches
                    }
                )
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 22)
    }

    private var missingProjectView: some View {
        Text("Proyecto no encontrado")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(StitchColors.text)
            .padding()
    }

    private var projectName: Binding<String> {
        Binding(
            get: {
                store.project(id: projectID)?.name ?? ""
            },
            set: { newName in
                store.updateName(for: projectID, name: newName)
            }
        )
    }

    private var stitchCounterName: Binding<String> {
        Binding(
            get: {
                store.project(id: projectID)?.stitchCounterName ?? StitchProject.defaultStitchCounterName
            },
            set: { newName in
                store.updateStitchCounterName(for: projectID, name: newName)
            }
        )
    }

    private var rowCounterName: Binding<String> {
        Binding(
            get: {
                store.project(id: projectID)?.rowCounterName ?? StitchProject.defaultRowCounterName
            },
            set: { newName in
                store.updateRowCounterName(for: projectID, name: newName)
            }
        )
    }

    private func reset(_ target: ResetTarget) {
        guard let project = store.project(id: projectID) else { return }

        switch target {
        case .rows:
            store.updateCounts(
                for: projectID,
                stitchCount: project.stitchCount,
                rowCount: 0
            )
        case .stitches:
            store.updateCounts(
                for: projectID,
                stitchCount: 0,
                rowCount: project.rowCount
            )
        }
    }

    private func displayCounterName(for target: ResetTarget) -> String {
        guard let project = store.project(id: projectID) else {
            return target.defaultName
        }

        switch target {
        case .rows:
            return project.displayRowCounterName
        case .stitches:
            return project.displayStitchCounterName
        }
    }
}

enum ResetTarget: Identifiable {
    case rows
    case stitches

    var id: String {
        switch self {
        case .rows:
            return "rows"
        case .stitches:
            return "stitches"
        }
    }

    var defaultName: String {
        switch self {
        case .rows:
            return StitchProject.defaultRowCounterName
        case .stitches:
            return StitchProject.defaultStitchCounterName
        }
    }
}

struct CounterCard: View {
    @Binding var title: String
    let defaultTitle: String
    let value: Int
    let accentColor: Color
    let minusAction: () -> Void
    let plusAction: () -> Void
    let resetAction: () -> Void

    private var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? defaultTitle : trimmedTitle
    }

    var body: some View {
        VStack(spacing: 18) {
            TextField(defaultTitle, text: $title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(StitchColors.text)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .accessibilityLabel("Nombre de \(defaultTitle.lowercased())")

            Text("\(value)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundColor(StitchColors.text)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .id(value)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("\(displayTitle): \(value)")

            HStack(spacing: 22) {
                RoundCounterButton(
                    symbol: "-",
                    backgroundColor: StitchColors.lavender,
                    foregroundColor: StitchColors.text,
                    action: minusAction
                )
                .accessibilityLabel("Restar \(displayTitle.lowercased())")

                RoundCounterButton(
                    symbol: "+",
                    backgroundColor: accentColor,
                    foregroundColor: .white,
                    action: plusAction
                )
                .accessibilityLabel("Sumar \(displayTitle.lowercased())")
            }

            Button(action: resetAction) {
                Text("Reiniciar \(displayTitle.lowercased())")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(StitchColors.softTerracotta)
                    .foregroundColor(StitchColors.text)
                    .cornerRadius(18)
            }
            .accessibilityLabel("Reiniciar \(displayTitle.lowercased())")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(StitchColors.card)
        .cornerRadius(28)
        .shadow(color: StitchColors.shadow, radius: 12, x: 0, y: 6)
    }
}

struct RoundCounterButton: View {
    let symbol: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .frame(width: 76, height: 76)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Circle())
        }
    }
}

struct StitchColors {
    static let background = Color(red: 0.98, green: 0.94, blue: 0.87)
    static let card = Color(red: 1.00, green: 0.98, blue: 0.94)
    static let text = Color(red: 0.29, green: 0.22, blue: 0.20)
    static let secondaryText = Color(red: 0.55, green: 0.45, blue: 0.42)
    static let dustyRose = Color(red: 0.78, green: 0.45, blue: 0.50)
    static let lavender = Color(red: 0.86, green: 0.80, blue: 0.91)
    static let sage = Color(red: 0.52, green: 0.64, blue: 0.50)
    static let terracotta = Color(red: 0.74, green: 0.38, blue: 0.30)
    static let softTerracotta = Color(red: 0.92, green: 0.73, blue: 0.66)
    static let shadow = Color(red: 0.42, green: 0.29, blue: 0.24).opacity(0.12)
}
