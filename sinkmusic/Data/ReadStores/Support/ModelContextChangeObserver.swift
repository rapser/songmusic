//
//  ModelContextChangeObserver.swift
//  sinkmusic
//

import Foundation
import SwiftData

/// Observa `ModelContext.didSave` y emite una señal cuando una entidad relevante cambió.
///
/// Reemplaza la necesidad de que los DataSources notifiquen explícitamente a la UI:
/// SwiftData ya avisa de cada `save()` exitoso vía NotificationCenter, con el
/// `PersistentIdentifier` de cada entidad insertada/actualizada/borrada. Este tipo
/// filtra esas notificaciones por nombre de entidad (`SongDTO`, `PlaylistDTO`, ...)
/// y las republica como un `AsyncStream<Void>` — una señal simple de "algo cambió,
/// vuelve a preguntar", sin acoplar el observer a qué hacer con el cambio.
///
/// **Coalescing con flanco de subida**: una acción de usuario suele producir varios
/// `save()` seguidos (p. ej. reproducir = contador + posición), y recargar N veces sería
/// absurdo. Pero un debounce *solo* de cola retrasaba **toda** señal 120 ms, incluida la
/// primera, y eso obligaba a los ViewModels a recargar también a mano tras cada mutación
/// para que la UI respondiera al instante — dos caminos al mismo dato.
///
/// Así que: si el observer llevaba en silencio más que la ventana, emite **ya**; si llegan
/// más `save()` dentro de la ventana, se agrupan en una única emisión de cola. Una
/// escritura suelta produce una señal inmediata; una ráfaga, dos (el arranque y el cierre)
/// en vez de una por escritura.
@MainActor
final class ModelContextChangeObserver {

    // El token de NotificationCenter no es Sendable y `removeObserver` es seguro de
    // invocar desde cualquier hilo, así que se accede sin el chequeo de aislamiento
    // de actor (sería imposible cumplirlo desde un deinit no-aislado).
    private nonisolated(unsafe) var token: NSObjectProtocol?
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    private let debounce: Duration
    private var pendingNotify: Task<Void, Never>?

    /// Cuándo se emitió por última vez, para distinguir "venía en silencio" de "estoy en
    /// medio de una ráfaga".
    private var lastNotifiedAt: ContinuousClock.Instant?

    /// Mientras está suspendido (p. ej. durante "Descargar todo"), los `save()` no disparan
    /// recargas: se acumulan en `pendingWhileSuspended` y se emite **una** señal al reanudar.
    private var isSuspended = false
    private var pendingWhileSuspended = false

    init(modelContext: ModelContext, relevantEntityNames: Set<String>, debounce: Duration = .milliseconds(120)) {
        self.debounce = debounce
        token = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: modelContext,
            queue: nil
        ) { [weak self] note in
            // `Notification` no es Sendable: se extrae la relevancia aquí mismo,
            // sin cruzar el note al Task aislado a MainActor.
            guard Self.isRelevant(note, relevantEntityNames: relevantEntityNames) else { return }
            Task { @MainActor [weak self] in
                self?.scheduleNotify()
            }
        }
    }

    /// Reprograma la emisión: si llegan más `save()` dentro de `debounce`, se colapsan en uno.
    private func scheduleNotify() {
        guard !isSuspended else {
            pendingWhileSuspended = true
            return
        }

        pendingNotify?.cancel()

        if isWithinBurst {
            // En medio de una ráfaga: una sola emisión cuando pare.
            pendingNotify = Task { [weak self] in
                try? await Task.sleep(for: self?.debounce ?? .milliseconds(120))
                guard !Task.isCancelled, let self else { return }
                self.notifyContinuations()
            }
        } else {
            // Veníamos en silencio: la UI debe responder ya, sin esperar la ventana.
            notifyContinuations()
        }
    }

    private var isWithinBurst: Bool {
        guard let lastNotifiedAt else { return false }
        return ContinuousClock.now - lastNotifiedAt < debounce
    }

    /// Pausa las emisiones (los cambios se acumulan). Reentrante vía el `ReactiveReloadGate`.
    func suspend() {
        isSuspended = true
    }

    /// Reanuda; si hubo algún cambio mientras estaba pausado, emite una única señal.
    func resume() {
        isSuspended = false
        if pendingWhileSuspended {
            pendingWhileSuspended = false
            scheduleNotify()
        }
    }

    func stream() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            self?.continuations[id] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func notifyContinuations() {
        lastNotifiedAt = ContinuousClock.now
        for (_, continuation) in continuations {
            continuation.yield(())
        }
    }

    private nonisolated static func isRelevant(_ note: Notification, relevantEntityNames: Set<String>) -> Bool {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        for key in keys {
            if let identifiers = note.userInfo?[key.rawValue] as? [PersistentIdentifier],
               identifiers.contains(where: { relevantEntityNames.contains($0.entityName) }) {
                return true
            }
        }
        return false
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
