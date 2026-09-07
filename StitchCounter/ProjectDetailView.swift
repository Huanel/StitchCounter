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
        .keepsScreenAwake()
        .onAppear(perform: Haptics.prepare)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                UndoButton()
            }
        }
        .alert(item: $resetTarget) { target in
            let counterName = displayCounterName(for: target)
            return Alert(
                title: Text("Reiniciar \(counterName.lowercased())"),
                message: Text("¿Querés volver \(counterName.lowercased()) a cero?"),
                primaryButton: .destructive(Text("Reiniciar")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        reset(target)
                    }
                    Haptics.completed()
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }

    private func counterContent(for project: StitchProject) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                EditableName(
                    placeholder: "Nombre del proyecto",
                    value: project.name,
                    autocapitalization: .words,
                    commit: { store.updateName(for: projectID, name: $0) }
                )
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(StitchColors.text)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Nombre del proyecto")

                Text("Contador de puntos y vueltas")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(StitchColors.secondaryText)
            }
            .padding(.top, 18)

            VStack(spacing: 18) {
                CounterCard(
                    title: project.rowCounterName,
                    commitTitle: { store.updateRowCounterName(for: projectID, name: $0) },
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
                    title: project.stitchCounterName,
                    commitTitle: { store.updateStitchCounterName(for: projectID, name: $0) },
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

/// Deshace el último cambio. Aparece solo cuando hay algo que deshacer, así que
/// su presencia ya dice que se puede volver atrás.
struct UndoButton: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        if store.canUndo {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.undo()
                }
                Haptics.completed()
            } label: {
                Label("Deshacer", systemImage: "arrow.uturn.backward")
            }
            .accessibilityLabel("Deshacer el último cambio")
        }
    }
}

/// Campo de texto que guarda cuando terminás de escribir, no en cada tecla.
///
/// El binding anterior mandaba cada carácter al store, y cada carácter volvía a
/// codificar la biblioteca entera y a sincronizarla con el reloj. Acá el texto
/// vive local mientras editás y se confirma al salir del campo, al enviar o al
/// dejar la pantalla: un solo guardado por cambio de nombre.
private struct EditableName: View {
    let placeholder: String
    let value: String
    let autocapitalization: TextInputAutocapitalization
    let commit: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .textInputAutocapitalization(autocapitalization)
            .submitLabel(.done)
            .focused($isEditing)
            .onAppear { draft = value }
            .onChange(of: value) { newValue in
                // Cambio de afuera (una sincronización desde el reloj): se
                // adopta solo si no lo estás editando, para no pisarte el texto.
                if !isEditing {
                    draft = newValue
                }
            }
            .onChange(of: isEditing) { editing in
                if !editing { save() }
            }
            .onSubmit(save)
            .onDisappear(perform: save)
    }

    private func save() {
        guard draft != value else { return }
        commit(draft)
    }
}

struct CounterCard: View {
    let title: String
    let commitTitle: (String) -> Void
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
            EditableName(
                placeholder: defaultTitle,
                value: title,
                autocapitalization: .sentences,
                commit: commitTitle
            )
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundColor(StitchColors.text)
            .multilineTextAlignment(.center)
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
                    // En cero el toque no cambia nada: hay que poder notar la
                    // diferencia entre "llegué al fondo" y "no registró".
                    isBlocked: value == 0,
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
    var isBlocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            if isBlocked {
                Haptics.blocked()
            } else {
                Haptics.counted()
            }
            action()
        } label: {
            Text(symbol)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .frame(width: 76, height: 76)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Circle())
        }
    }
}

/// Mantiene la pantalla encendida mientras el contador está a la vista.
///
/// Tejiendo pasan minutos entre toque y toque, y el teléfono se apaga justo a
/// mitad de una vuelta. El temporizador vuelve a su comportamiento normal al
/// salir de la pantalla, así que la app no deja el teléfono despierto de fondo.
private struct KeepsScreenAwake: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

private extension View {
    func keepsScreenAwake() -> some View {
        modifier(KeepsScreenAwake())
    }
}
