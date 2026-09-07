import Foundation
import WatchConnectivity

/// Puente entre el iPhone y el Apple Watch.
///
/// Usa `updateApplicationContext`, que guarda un único estado pendiente y lo
/// entrega en cuanto el otro lado aparece — aunque esté apagado o sin la app
/// abierta ahora mismo. Es exactamente lo que hace falta acá: no interesa el
/// historial de cambios, solo el estado más reciente.
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    /// Se llama siempre en el hilo principal.
    var onReceive: ((ProjectSnapshot) -> Void)?

    /// Avisa que la sesión quedó lista. Sirve para publicar el estado local sin
    /// esperar a una edición: si no, un reloj recién instalado no vería los
    /// proyectos del teléfono hasta que tocaras algo. Siempre en el hilo principal.
    var onReady: (() -> Void)?

    private let payloadKey = "snapshot"
    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    var isSupported: Bool { WCSession.isSupported() }

    private override init() {
        super.init()
    }

    func start() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            deliverPendingContext(from: session)
            notifyReady()
        }
    }

    private func notifyReady() {
        if Thread.isMainThread {
            onReady?()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onReady?()
            }
        }
    }

    /// Publica el estado actual. Reemplaza cualquier envío pendiente, así que
    /// llamarla seguido no encola trabajo: siempre viaja una sola versión.
    func send(_ snapshot: ProjectSnapshot) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder.sync.encode(snapshot) else { return }

        do {
            try session.updateApplicationContext([payloadKey: data])
        } catch {
            // No hay contraparte todavía, o el contexto es idéntico al anterior.
            // El próximo cambio lo reintenta; no hay nada que reparar acá.
        }
    }

    private func deliverPendingContext(from session: WCSession) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        handle(context)
    }

    private func handle(_ context: [String: Any]) {
        guard let data = context[payloadKey] as? Data,
              let snapshot = try? JSONDecoder.sync.decode(ProjectSnapshot.self, from: data) else {
            return
        }

        if Thread.isMainThread {
            onReceive?(snapshot)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onReceive?(snapshot)
            }
        }
    }
}

extension WatchSyncService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        // Al activar puede haber un estado que llegó con la app cerrada.
        deliverPendingContext(from: session)
        notifyReady()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

#if os(iOS)
    /// Se dispara cuando el reloj se empareja o cuando recién se instala la app
    /// en él. Sin esto, un reloj al que le acaban de instalar la app no recibe
    /// nada hasta que edites algo en el teléfono: en la activación anterior el
    /// envío falló porque todavía no había app del otro lado.
    func sessionWatchStateDidChange(_ session: WCSession) {
        guard session.activationState == .activated else { return }
        notifyReady()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Cambió el reloj emparejado: hay que reactivar para seguir hablando
        // con el nuevo.
        session.activate()
    }
#endif
}

extension JSONEncoder {
    static var sync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var sync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
