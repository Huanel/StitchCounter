import SwiftUI

struct ContentView: View {
    @AppStorage("rowCount") private var rowCount = 0
    @AppStorage("stitchCount") private var stitchCount = 0

    var body: some View {
        TabView {
            WatchCounterView(title: "Vueltas", value: $rowCount, tint: .pink)
            WatchCounterView(title: "Puntos", value: $stitchCount, tint: .green)
        }
        .tabViewStyle(.verticalPage)
    }
}

private struct WatchCounterView: View {
    let title: String
    @Binding var value: Int
    let tint: Color

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
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Restar \(title.lowercased())")

                Button {
                    value += 1
                } label: {
                    Image(systemName: "plus")
                }
                .tint(tint)
                .accessibilityLabel("Sumar \(title.lowercased())")
            }

            Button("Reiniciar") {
                value = 0
            }
            .font(.footnote)
        }
        .padding(.horizontal)
    }
}
