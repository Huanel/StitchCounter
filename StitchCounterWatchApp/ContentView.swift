import SwiftUI
import WatchKit

struct ContentView: View {
    @AppStorage("rowCount") private var rowCount = 0
    @AppStorage("stitchCount") private var stitchCount = 0
    @State private var resetTarget: WatchCounterTarget?

    var body: some View {
        TabView {
            WatchCounterView(
                title: "Puntos",
                value: $stitchCount,
                tint: .green,
                resetAction: { resetTarget = .stitches }
            )

            WatchCounterView(
                title: "Vueltas",
                value: $rowCount,
                tint: .pink,
                resetAction: { resetTarget = .rows }
            )
        }
        .watchPageStyleIfAvailable()
        .alert(item: $resetTarget) { target in
            Alert(
                title: Text(target.resetTitle),
                message: Text("¿Querés volver a cero?"),
                primaryButton: .destructive(Text("Reiniciar")) {
                    switch target {
                    case .stitches:
                        stitchCount = 0
                    case .rows:
                        rowCount = 0
                    }
                    WKInterfaceDevice.current().play(.success)
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
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

    var resetTitle: String {
        switch self {
        case .stitches:
            return "Reiniciar puntos"
        case .rows:
            return "Reiniciar vueltas"
        }
    }
}

private struct WatchCounterView: View {
    let title: String
    @Binding var value: Int
    let tint: Color
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)

            Text(value.formatted())
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("\(title): \(value)")

            HStack(spacing: 10) {
                Button {
                    if value > 0 {
                        value -= 1
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Restar \(title.lowercased())")

                Button {
                    value += 1
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(tint)
                .accessibilityLabel("Sumar \(title.lowercased())")
            }

            Button {
                resetAction()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .font(.footnote)
            .accessibilityLabel("Reiniciar \(title.lowercased())")
        }
        .padding(.horizontal)
    }
}
