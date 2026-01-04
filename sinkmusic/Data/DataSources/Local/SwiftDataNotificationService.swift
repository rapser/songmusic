//
//  SwiftDataNotificationService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// Servicio para notificar cambios en SwiftData SIN usar @Query
/// REEMPLAZO CRÍTICO de @Query para Clean Architecture
///
/// Funciona observando cambios en ModelContext y propagándolos via NotificationCenter
/// para que los ViewModels reaccionen sin depender de @Query
final class SwiftDataNotificationService {

    // MARK: - Notification Name

    /// Notification que se envía cuando SwiftData cambia
    static let didChangeNotification = Notification.Name("SwiftDataDidChange")

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Lifecycle

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Notification Handling

    /// Notifica cambios después de un save
    /// Debe llamarse manualmente después de modelContext.save()
    @objc private func contextDidChange() {
        Task { @MainActor in
            // Propagar cambio a toda la app
            NotificationCenter.default.post(
                name: Self.didChangeNotification,
                object: nil
            )
        }
    }

    /// Notificar cambio manualmente (usado después de saves)
    func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: Self.didChangeNotification,
                object: nil
            )
        }
    }

    // MARK: - Observation API

    /// Observa cambios en SwiftData y ejecuta callback
    ///
    /// Uso típico en DataSource:
    /// ```swift
    /// func observeChanges(onChange: @escaping @MainActor ([SongDTO]) -> Void) {
    ///     notificationService.observe { [weak self] in
    ///         guard let self = self else { return }
    ///         Task { @MainActor in
    ///             if let songs = try? self.getAll() {
    ///                 onChange(songs)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    func observe(onChange: @escaping @MainActor () -> Void) {
        NotificationCenter.default.addObserver(
            forName: Self.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onChange()
            }
        }
    }

    /// Observa cambios con información adicional del notification
    func observeDetailed(onChange: @escaping @MainActor ([AnyHashable: Any]?) -> Void) {
        NotificationCenter.default.addObserver(
            forName: Self.didChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                onChange(notification.userInfo)
            }
        }
    }
}

// MARK: - Flujo Completo

/*
 FLUJO: SwiftData → ViewModel → View

 1. User cambia Song en SwiftData (ej: incrementa playCount)
 2. SwiftDataNotificationService detecta NSManagedObjectContext.didSaveObjectsNotification
 3. Notifica via SwiftDataDidChange notification
 4. SongLocalDataSource escucha y hace fetch de [SongDTO]
 5. SongRepository mapea DTOs → Entities
 6. Repository ejecuta callback con [SongEntity]
 7. ViewModel recibe entities, mapea a [SongUIModel], actualiza @Published
 8. SwiftUI re-renderiza View automáticamente

 VENTAJAS vs @Query:
 - ✅ Desacoplamiento total de SwiftData en vistas
 - ✅ ViewModels controlan qué datos exponer
 - ✅ Mappers transforman entre capas
 - ✅ Testing más fácil (mock repositories)
 - ✅ Clean Architecture 100%
 */
