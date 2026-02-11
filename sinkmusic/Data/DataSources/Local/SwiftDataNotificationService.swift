//
//  SwiftDataNotificationService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//  Refactored to use EventBus (Clean Architecture)
//

import Foundation
import SwiftData

/// Servicio para notificar cambios en SwiftData usando EventBus
/// REEMPLAZO CRÍTICO de @Query para Clean Architecture
///
/// ## Flujo
/// 1. DataSource hace cambios en SwiftData
/// 2. DataSource llama `notifyChange()` o `notifySongDownloaded(id)`
/// 3. EventBus emite el evento apropiado
/// 4. ViewModels suscritos via `for await` reciben el evento
/// 5. ViewModels actualizan su estado y SwiftUI re-renderiza
///
/// SOLID: Dependency Inversion - Depende de EventBusProtocol
final class SwiftDataNotificationService {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let eventBus: EventBusProtocol

    // MARK: - Lifecycle

    init(modelContext: ModelContext, eventBus: EventBusProtocol) {
        self.modelContext = modelContext
        self.eventBus = eventBus
    }

    // MARK: - Event Emission

    /// Notificar que las canciones fueron actualizadas
    /// Llamar después de cualquier operación que modifique canciones
    func notifyChange() {
        Task { @MainActor [eventBus] in
            eventBus.emit(.songsUpdated)
        }
    }

    /// Notificar que una canción fue descargada
    /// - Parameter songID: ID de la canción descargada
    func notifySongDownloaded(_ songID: UUID) {
        Task { @MainActor [eventBus] in
            eventBus.emit(.songDownloaded(songID))
        }
    }

    /// Notificar que una canción fue eliminada
    /// - Parameter songID: ID de la canción eliminada
    func notifySongDeleted(_ songID: UUID) {
        Task { @MainActor [eventBus] in
            eventBus.emit(.songDeleted(songID))
        }
    }

    /// Notificar que las playlists fueron actualizadas
    func notifyPlaylistsChange() {
        Task { @MainActor [eventBus] in
            eventBus.emit(.playlistsUpdated)
        }
    }

    /// Notificar que las credenciales cambiaron
    func notifyCredentialsChange() {
        Task { @MainActor [eventBus] in
            eventBus.emit(.credentialsChanged)
        }
    }
}

// MARK: - Flujo Completo

/*
 FLUJO: SwiftData → ViewModel → View (con EventBus + DI)

 1. User cambia Song en SwiftData (ej: incrementa playCount)
 2. DataSource llama notificationService.notifyChange()
 3. eventBus.emit(.songsUpdated)  // EventBus inyectado via DI
 4. ViewModel recibe evento via `for await event in eventBus.dataEvents()`
 5. ViewModel hace fetch de datos actualizados
 6. ViewModel mapea a UIModels y actualiza propiedades @Observable
 7. SwiftUI re-renderiza View automáticamente

 VENTAJAS vs NotificationCenter:
 - ✅ Type-safe: Eventos son enums tipados
 - ✅ Modern: AsyncStream en lugar de addObserver/removeObserver
 - ✅ Memory safe: Task cancellation automático
 - ✅ Clean Architecture: Sin strings mágicos, DI puro
 - ✅ Testable: EventBus es mockeable via EventBusProtocol
 */
