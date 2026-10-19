//
//  EventBus.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Core Layer - Event Bus for Clean Architecture
//

import Foundation

/// Bus de eventos centralizado para comunicación de eventos verdaderamente globales/cross-cutting:
/// autenticación, reproducción (Live Activity, remote control) y descargas.
///
/// La reactividad local de listas (Home/Library/Playlist/Search) NO pasa por aquí — vive en los
/// `ReadStoreProtocol` de cada dominio (`Domain/ReadStores/`), que reaccionan directamente a
/// `ModelContext.didSave` de SwiftData. Ver `ModelContextChangeObserver`.
///
/// Es **solo un bus de eventos efímeros**: no guarda estado. Cada consumidor mantiene el
/// suyo (p. ej. `PlayerViewModel.progress`). Antes duplicaba aquí el estado de reproducción
/// y de sesión en propiedades `@Observable` que no leía nadie — una tercera copia de la
/// verdad que solo podía desincronizarse.
///
/// AsyncStream para eventos. Reactividad moderna iOS 18+ / Swift 6
///
/// ## Principios
/// - **Type-safe:** Todos los eventos son enums/structs tipados
/// - **Reactive:** AsyncStream para suscripciones asíncronas
/// - **Clean Architecture:** Comunicación sin acoplar capas
/// - **Memory Safe:** Task cancellation automático
///
/// ## Uso (via DIContainer)
///
/// ### Publicar evento (desde Service/DataSource)
/// ```swift
/// eventBus.emit(.stateChanged(isPlaying: true, songID: id))
/// ```
///
/// ### Suscribirse (desde ViewModel)
/// ```swift
/// Task { [weak self] in
///     for await event in eventBus.playbackEvents() {
///         self?.handleEvent(event)
///     }
/// }
/// ```
///
/// SOLID: Conforma a EventBusProtocol para Dependency Inversion
/// NO usa singleton - Obtener instancia de DIContainer.shared.eventBus
@MainActor
final class EventBus: EventBusProtocol {

    // MARK: - Stream Continuations

    private var playbackEventContinuations: [UUID: AsyncStream<PlaybackEvent>.Continuation] = [:]
    private var downloadEventContinuations: [UUID: AsyncStream<DownloadEvent>.Continuation] = [:]

    // MARK: - Emit Playback Events

    /// Emitir evento de reproducción
    func emit(_ event: PlaybackEvent) {
        for (_, continuation) in playbackEventContinuations {
            continuation.yield(event)
        }
    }

    // MARK: - Emit Download Events

    /// Emitir evento de descarga
    func emit(_ event: DownloadEvent) {
        for (_, continuation) in downloadEventContinuations {
            continuation.yield(event)
        }
    }

    // MARK: - AsyncStream Factories

    // El registro de la continuation es **síncrono**, antes de devolver el stream.
    //
    // Guardarla dentro de un `Task { @MainActor }` abría una ventana entre que el stream se
    // devolvía y la tarea corría: cualquier `emit` en ese hueco no veía al suscriptor y el
    // evento se perdía sin rastro. `makeStream()` entrega la continuation en mano, así que
    // cuando el llamador recibe el stream ya está registrado.
    //
    // `onTermination` sí queda diferido: lo invoca el runtime desde cualquier hilo y solo
    // limpia el diccionario, así que llegar tarde es inofensivo.

    /// Stream de eventos de reproducción
    /// - Returns: AsyncStream que emite PlaybackEvent
    func playbackEvents() -> AsyncStream<PlaybackEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<PlaybackEvent>.makeStream()
        playbackEventContinuations[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playbackEventContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    /// Stream de eventos de descarga
    /// - Returns: AsyncStream que emite DownloadEvent
    func downloadEvents() -> AsyncStream<DownloadEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DownloadEvent>.makeStream()
        downloadEventContinuations[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.downloadEventContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    // MARK: - Lifecycle

    /// Inicializador público para permitir inyección de dependencias
    /// En producción, usar la instancia del DIContainer
    init() {}

    // MARK: - Testing Support

    #if DEBUG
    /// Reset all state (for testing only)
    func reset() {
        // Finish all streams
        for (_, continuation) in playbackEventContinuations {
            continuation.finish()
        }
        for (_, continuation) in downloadEventContinuations {
            continuation.finish()
        }

        playbackEventContinuations.removeAll()
        downloadEventContinuations.removeAll()
    }
    #endif
}
