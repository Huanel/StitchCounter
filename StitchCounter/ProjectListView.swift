import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var path: [StitchProject.ID] = []
    @State private var projectPendingDeletion: StitchProject?

    /// En iPhone el alto compacto significa apaisado.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                StitchColors.background
                    .ignoresSafeArea()

                // Un solo scroll para encabezado y lista: antes el encabezado
                // quedaba fijo afuera y en apaisado se comía media pantalla.
                //
                // Sin GeometryReader a propósito. Envolviendo este ScrollView,
                // al rotar cambiaba la geometría y el LazyVStack de adentro
                // soltaba sus celdas sin volver a crearlas: las filas quedaban
                // en blanco. El size class del entorno responde lo mismo sin
                // medir nada.
                ScrollView {
                    VStack(spacing: isLandscape ? 14 : 22) {
                        header(isLandscape: isLandscape)

                        if store.projects.isEmpty {
                            emptyState
                        } else {
                            projectList
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, isLandscape ? 6 : 18)
                    .padding(.bottom, 20)
                }
            }
            // Sin título en la barra: el encabezado ya dice "StitchCounter" y
            // "Proyectos" justo debajo, y repetirlo arriba solo agrega una
            // franja más en una pantalla que se lee de un vistazo.
            .navigationBarTitleDisplayMode(.inline)
            // Sin fondo de barra: al scrollear, iOS le pone un material
            // difuminado y una línea divisoria, y esa franja corta el crema.
            // Oculto, el fondo de la app sigue de largo y los botones —que
            // traen su propia cápsula— se leen igual sobre el contenido.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    UndoButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addProject) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Agregar proyecto")
                }
            }
            .navigationDestination(for: StitchProject.ID.self) { projectID in
                ProjectDetailView(projectID: projectID)
            }
            .alert(item: $projectPendingDeletion) { project in
                Alert(
                    title: Text("Borrar proyecto"),
                    message: Text("¿Querés borrar \"\(project.displayName)\" y su contador?"),
                    primaryButton: .destructive(Text("Borrar")) {
                        store.deleteProject(id: project.id)
                        Haptics.completed()
                    },
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            }
        }
        .tint(StitchColors.terracotta)
    }

    private func header(isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 10 : 14) {
            VStack(spacing: 6) {
                Text("StitchCounter")
                    .font(.system(
                        size: isLandscape ? 24 : 34,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundColor(StitchColors.text)

                // La barra de navegación ya dice "Proyectos"; de costado el
                // alto vale más que repetirlo.
                if !isLandscape {
                    Text("Proyectos")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(StitchColors.secondaryText)
                }
            }

            Button(action: addProject) {
                Label("Agregar proyecto", systemImage: "plus")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isLandscape ? 10 : 14)
                    .background(StitchColors.dustyRose)
                    .foregroundColor(.white)
                    .cornerRadius(18)
            }
            .accessibilityLabel("Agregar proyecto")
        }
    }

    private var projectList: some View {
        LazyVStack(spacing: 14) {
            ForEach(store.projects) { project in
                ProjectRow(
                    project: project,
                    deleteAction: {
                        projectPendingDeletion = project
                    }
                )
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Todavía no hay proyectos")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(StitchColors.text)

            Text("Agregá uno para empezar a contar puntos y vueltas.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(StitchColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(StitchColors.card)
        .cornerRadius(24)
        .shadow(color: StitchColors.shadow, radius: 12, x: 0, y: 6)
    }

    private func addProject() {
        let project = store.addProject()
        path.append(project.id)
    }
}

private struct ProjectRow: View {
    let project: StitchProject
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: project.id) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.displayName)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(StitchColors.text)
                            .lineLimit(2)

                        HStack(spacing: 14) {
                            CounterSummaryLabel(
                                title: project.displayRowCounterName,
                                value: project.rowCount
                            )

                            CounterSummaryLabel(
                                title: project.displayStitchCounterName,
                                value: project.stitchCount
                            )
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(StitchColors.secondaryText)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: deleteAction) {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(StitchColors.softTerracotta)
                    .foregroundColor(StitchColors.text)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Borrar \(project.displayName)")
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .background(StitchColors.card)
        .cornerRadius(24)
        .shadow(color: StitchColors.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct CounterSummaryLabel: View {
    let title: String
    let value: Int

    var body: some View {
        Text("\(title): \(value)")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(StitchColors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
