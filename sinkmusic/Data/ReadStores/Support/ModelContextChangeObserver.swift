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
@MainActor
final class ModelContextChangeObserver {

    // El token de NotificationCenter no es Sendable y `removeObserver` es seguro de
    // invocar desde cualquier hilo, así que se accede sin el chequeo de aislamiento
    // de actor (sería imposible cumplirlo desde un deinit no-aislado).
    private nonisolated(unsafe) var token: NSObjectProtocol?
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(modelContext: ModelContext, relevantEntityNames: Set<String>) {
        token = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: modelContext,
            queue: nil
        ) { [weak self] note in
            // `Notification` no es Sendable: se extrae la relevancia aquí mismo,
            // sin cruzar el note al Task aislado a MainActor.
            guard Self.isRelevant(note, relevantEntityNames: relevantEntityNames) else { return }
            Task { @MainActor [weak self] in
                self?.notifyContinuations()
            }
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
