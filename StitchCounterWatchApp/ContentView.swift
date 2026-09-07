import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.projects) { project in
                    NavigationLink {
                        WatchProjectView(projectID: project.id)
                    } label: {
                        WatchProjectRow(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)

                Button(action: addProject) {
                    Label("Agregar proyecto", systemImage: "plus")
                }

                if store.canUndo {
                    Button(action: undo) {
                        Label("Deshacer", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .navigationTitle("Proyectos")
            .overlay {
                if store.projects.isEmpty {
                    WatchEmptyState(addAction: addProject)
                }
            }
        }
    }

    private func addProject() {
        store.addProject()
        WKInterfaceDevice.current().play(.click)
    }

    private func undo() {
        store.undo()
        WKInterfaceDevice.current().play(.success)
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            store.deleteProject(id: store.projects[index].id)
        }
        WKInterfaceDevice.current().play(.success)
    }
}

private struct WatchProjectRow: View {
    let project: StitchProject

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(project.displayName)
                .font(.headline)
                .lineLimit(1)

            Text("\(project.displayRowCounterName) \(project.rowCount) · \(project.displayStitchCounterName) \(project.stitchCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 2)
    }
}

private struct WatchEmptyState: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Todavía no hay proyectos")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Agregá uno acá o en el iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Agregar", action: addAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.background)
    }
}

private struct WatchProjectView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var resetTarget: WatchCounterTarget?

    let projectID: StitchProject.ID

    var body: some View {
        Group {
            if let project = store.project(id: projectID) {
                TabView {
                    WatchCounterView(
                        title: project.displayRowCounterName,
                        value: project.rowCount,
                        tint: StitchColors.dustyRose,
                        minusAction: { store.adjustRowCount(for: projectID, by: -1) },
                        plusAction: { store.adjustRowCount(for: projectID, by: 1) },
                        resetAction: { resetTarget = .rows }
                    )

                    WatchCounterView(
                        title: project.displayStitchCounterName,
                        value: project.stitchCount,
                        tint: StitchColors.sage,
                        minusAction: { store.adjustStitchCount(for: projectID, by: -1) },
                        plusAction: { store.adjustStitchCount(for: projectID, by: 1) },
                        resetAction: { resetTarget = .stitches }
                    )
                }
                .watchPageStyleIfAvailable()
                .navigationTitle(project.displayName)
            } else {
                Text("Proyecto no encontrado")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(item: $resetTarget) { target in
            Alert(
                title: Text(resetTitle(for: target)),
                message: Text("¿Querés volver a cero?"),
                primaryButton: .destructive(Text("Reiniciar")) {
                    reset(target)
                    WKInterfaceDevice.current().play(.success)
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }

    private func reset(_ target: WatchCounterTarget) {
        switch target {
        case .rows:
            store.updateRowCount(for: projectID, rowCount: 0)
        case .stitches:
            store.updateStitchCount(for: projectID, stitchCount: 0)
        }
    }

    private func resetTitle(for target: WatchCounterTarget) -> String {
        guard let project = store.project(id: projectID) else {
            return "Reiniciar"
        }

        switch target {
        case .rows:
            return "Reiniciar \(project.displayRowCounterName.lowercased())"
        case .stitches:
            return "Reiniciar \(project.displayStitchCounterName.lowercased())"
        }
    }
}

private extension View {
    @ViewBuilder
    func watchPageStyleIfAvailable() -> some View {
        if #available(watchOS 10.0, *) {
            tabViewStyle(.verticalPage)
        } else {
            self
        }
    }
}

private enum WatchCounterTarget: Identifiable {
    case stitches
    case rows

    var id: String {
        switch self {
        case .stitches:
            return "stitches"
        case .rows:
            return "rows"
        }
    }
}

private struct WatchCounterView: View {
    let title: String
    let value: Int
    let tint: Color
    let minusAction: () -> Void
    let plusAction: () -> Void
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            // La pagina del TabView llega hasta el borde superior, debajo de la
            // barra con el nombre del proyecto. Este aire evita que el titulo
            // del contador quede pisado por ella.
            Spacer(minLength: 22)

            Text(title)
                .font(.headline)
                .foregroundStyle(StitchColors.softTerracotta)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value.formatted())
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("\(title): \(value)")

            HStack(spacing: 12) {
                CircleButton(symbol: "minus", fill: StitchColors.lavender, ink: StitchColors.text) {
                    guard value > 0 else {
                        WKInterfaceDevice.current().play(.failure)
                        return
                    }
                    minusAction()
                    WKInterfaceDevice.current().play(.click)
                }
                .accessibilityLabel("Restar \(title.lowercased())")

                CircleButton(symbol: "plus", fill: tint, ink: .white) {
                    plusAction()
                    WKInterfaceDevice.current().play(.click)
                }
                .accessibilityLabel("Sumar \(title.lowercased())")
            }

            Button(action: resetAction) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StitchColors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(StitchColors.softTerracotta)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reiniciar \(title.lowercased())")

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
    }
}

/// Boton redondo y solido, el mismo gesto visual que los del iPhone. En watchOS
/// `.tint` solo pinta el glifo de un boton con borde, no su relleno, asi que el
/// color de la app se pone a mano.
private struct CircleButton: View {
    let symbol: String
    let fill: Color
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .bold))
                .frame(width: 46, height: 46)
                .background(fill)
                .foregroundStyle(ink)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
