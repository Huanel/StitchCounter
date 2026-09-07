import UIKit

/// Respuestas al tacto para poder contar sin mirar la pantalla.
///
/// Cada caso dice algo distinto con el dedo: que el toque entró, que llegaste
/// al fondo y no se puede bajar más, o que una acción terminó. Es el mismo
/// vocabulario que ya usa la app del reloj con `WKInterfaceDevice`.
enum Haptics {
    /// El contador cambió. Corto y seco: es el golpecito de cada punto.
    static func counted() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// El toque no hizo nada porque el contador ya estaba en cero. Sin esto,
    /// un "−" en el fondo se siente igual que un toque perdido.
    static func blocked() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Una acción con peso terminó: reiniciar un contador, borrar un proyecto.
    static func completed() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Le avisa al motor háptico que se prepare. Llamarlo justo antes de que el
    /// dedo llegue al botón hace que el golpecito salga sin retraso.
    static func prepare() {
        UIImpactFeedbackGenerator(style: .light).prepare()
    }
}
