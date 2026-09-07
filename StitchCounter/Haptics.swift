import UIKit

/// Respuestas al tacto para poder contar sin mirar la pantalla.
///
/// Cada caso dice algo distinto con el dedo: que el toque entró, que llegaste
/// al fondo y no se puede bajar más, o que una acción terminó. Es el mismo
/// vocabulario que ya usa la app del reloj con `WKInterfaceDevice`.
///
/// Los generadores viven acá y no dentro de cada función a propósito. Uno
/// creado y descartado en la misma línea se libera antes de que el motor
/// háptico llegue a usarlo, y el golpecito sale débil o directamente no sale;
/// además `prepare()` sobre una instancia distinta de la que después dispara no
/// prepara nada. Manteniéndolos vivos el motor queda listo y responde siempre.
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()

    /// El contador cambió. Corto y seco: es el golpecito de cada punto.
    static func counted() {
        impact.impactOccurred()
        // Deja el motor listo para el toque siguiente, que en esta app llega
        // enseguida: se cuenta punto tras punto.
        impact.prepare()
    }

    /// El toque no hizo nada porque el contador ya estaba en cero. Sin esto,
    /// un "−" en el fondo se siente igual que un toque perdido.
    static func blocked() {
        notification.notificationOccurred(.warning)
    }

    /// Una acción con peso terminó: reiniciar un contador, borrar un proyecto.
    static func completed() {
        notification.notificationOccurred(.success)
    }

    /// Le avisa al motor háptico que se prepare. Llamarlo al abrir la pantalla
    /// hace que el primer golpecito salga sin retraso.
    static func prepare() {
        impact.prepare()
        notification.prepare()
    }
}
