import SwiftUI

struct ContentView: View {
    @AppStorage("rowCount") private var rowCount = 0
    @AppStorage("stitchCount") private var stitchCount = 0

    @State private var resetTarget: ResetTarget?

    var body: some View {
        ZStack {
            StitchColors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Stitch Counter")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(StitchColors.text)

                    Text("Contador de puntos y vueltas")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(StitchColors.secondaryText)
                }
                .padding(.top, 18)

                VStack(spacing: 18) {
                    CounterCard(
                        title: "Vueltas",
                        value: rowCount,
                        accentColor: StitchColors.dustyRose,
                        resetTitle: "Reiniciar vueltas",
                        minusAction: {
                            if rowCount > 0 {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    rowCount -= 1
                                }
                            }
                        },
                        plusAction: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                rowCount += 1
                            }
                        },
                        resetAction: {
                            resetTarget = .rows
                        }
                    )

                    CounterCard(
                        title: "Puntos",
                        value: stitchCount,
                        accentColor: StitchColors.sage,
                        resetTitle: "Reiniciar puntos",
                        minusAction: {
                            if stitchCount > 0 {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    stitchCount -= 1
                                }
                            }
                        },
                        plusAction: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                stitchCount += 1
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
        .alert(item: $resetTarget) { target in
            Alert(
                title: Text(target.alertTitle),
                message: Text(target.alertMessage),
                primaryButton: .destructive(Text("Reiniciar")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switch target {
                        case .rows:
                            rowCount = 0
                        case .stitches:
                            stitchCount = 0
                        }
                    }
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
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

    var alertTitle: String {
        switch self {
        case .rows:
            return "Reiniciar vueltas"
        case .stitches:
            return "Reiniciar puntos"
        }
    }

    var alertMessage: String {
        switch self {
        case .rows:
            return "¿Querés volver las vueltas a cero?"
        case .stitches:
            return "¿Querés volver los puntos a cero?"
        }
    }
}

struct CounterCard: View {
    let title: String
    let value: Int
    let accentColor: Color
    let resetTitle: String
    let minusAction: () -> Void
    let plusAction: () -> Void
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(StitchColors.text)

            Text("\(value)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundColor(StitchColors.text)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .id(value)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("\(title): \(value)")

            HStack(spacing: 22) {
                RoundCounterButton(
                    symbol: "-",
                    backgroundColor: StitchColors.lavender,
                    foregroundColor: StitchColors.text,
                    action: minusAction
                )
                .accessibilityLabel("Restar \(title.lowercased())")

                RoundCounterButton(
                    symbol: "+",
                    backgroundColor: accentColor,
                    foregroundColor: .white,
                    action: plusAction
                )
                .accessibilityLabel("Sumar \(title.lowercased())")
            }

            Button(action: resetAction) {
                Text(resetTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(StitchColors.softTerracotta)
                    .foregroundColor(StitchColors.text)
                    .cornerRadius(18)
            }
            .accessibilityLabel(resetTitle)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
