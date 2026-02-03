//
//  EventBus.swift
//  sinkmusic
//
//  Created by Claude Code
//  Core Layer - Event Bus for Clean Architecture
//

import Foundation

/// Bus de eventos centralizado para comunicación entre capas
///
/// Usa @Observable para estado observable + AsyncStream para eventos
/// Reactividad moderna iOS 18+ / Swift 6
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
/// eventBus.emit(.songsUpdated)
/// eventBus.emit(.stateChanged(isPlaying: true, songID: id))
/// ```
///
/// ### Suscribirse (desde ViewModel)
/// ```swift
/// Task { [weak self] in
///     for await event in eventBus.dataEvents() {
///         self?.handleEvent(event)
///     }
/// }
/// ```
///
/// SOLID: Conforma a EventBusProtocol para Dependency Inversion
/// NO usa singleton - Obtener instancia de DIContainer.shared.eventBus
@MainActor
@Observable
final class EventBus: EventBusProtocol, @unchecked Sendable {

    // MARK: - Observable State

    /// Último evento de datos (para observación directa en SwiftUI)
    private(set) var lastDataEvent: DataChangeEvent?

    /// ID del usuario autenticado (nil si no hay sesión)
    private(set) var authUserID: String?

    /// Indica si hay un usuario autenticado
    var isAuthenticated: Bool { authUserID != nil }

    /// Estado actual de reproducción
    private(set) var playbackState: PlaybackState = .idle

    /// Información de tiempo de reproducción
    private(set) var playbackTimeInfo: PlaybackTimeInfo = .zero

    // MARK: - Stream Continuations

    private var dataEventContinuations: [UUID: AsyncStream<DataChangeEvent>.Continuation] = [:]
    private var authEventContinuations: [UUID: AsyncStream<AuthEvent>.Continuation] = [:]
    private var playbackEventContinuations: [UUID: AsyncStream<PlaybackEvent>.Continuation] = [:]
    private var downloadEventContinuations: [UUID: AsyncStream<DownloadEvent>.Continuation] = [:]

    // MARK: - Emit Data Events

    /// Emitir evento de cambio de datos
    func emit(_ event: DataChangeEvent) {
        lastDataEvent = event
        for (_, continuation) in dataEventContinuations {
            continuation.yield(event)
        }
    }

    // MARK: - Emit Auth Events

    /// Emitir evento de autenticación
    func emit(_ event: AuthEvent) {
        updateAuthState(from: event)
        for (_, continuation) in authEventContinuations {
            continuation.yield(event)
        }
    }

    private func updateAuthState(from event: AuthEvent) {
        switch event {
        case .signedIn(let userID, _, _):
            authUserID = userID
        case .signedOut:
            authUserID = nil
        case .checkCompleted(let isAuthenticated):
            if !isAuthenticated {
                authUserID = nil
            }
            // Si isAuthenticated es true, mantener el userID actual
        }
    }

    // MARK: - Emit Playback Events

    /// Emitir evento de reproducción
    func emit(_ event: PlaybackEvent) {
        updatePlaybackState(from: event)
        for (_, continuation) in playbackEventContinuations {
            continuation.yield(event)
        }
    }

    private func updatePlaybackState(from event: PlaybackEvent) {
        switch event {
        case .stateChanged(let isPlaying, let songID):
            if let songID = songID {
                playbackState = isPlaying ? .playing(songID: songID) : .paused(songID: songID)
            } else {
                playbackState = .idle
            }
        case .timeUpdated(let current, let duration):
            playbackTimeInfo = PlaybackTimeInfo(currentTime: current, duration: duration)
        case .songFinished:
            playbackState = .idle
        case .remoteCommand:
            // Remote commands don't change state directly
            break
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

    /// Stream de eventos de datos
    /// - Returns: AsyncStream que emite DataChangeEvent
    func dataEvents() -> AsyncStream<DataChangeEvent> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.dataEventContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dataEventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Stream de eventos de autenticación
    /// - Returns: AsyncStream que emite AuthEvent
    func authEvents() -> AsyncStream<AuthEvent> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.authEventContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.authEventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Stream de eventos de reproducción
    /// - Returns: AsyncStream que emite PlaybackEvent
    func playbackEvents() -> AsyncStream<PlaybackEvent> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.playbackEventContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.playbackEventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Stream de eventos de descarga
    /// - Returns: AsyncStream que emite DownloadEvent
    func downloadEvents() -> AsyncStream<DownloadEvent> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.downloadEventContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.downloadEventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    // MARK: - Lifecycle

    /// Inicializador público para permitir inyección de dependencias
    /// En producción, usar la instancia del DIContainer
    init() {}

    // MARK: - Testing Support

    #if DEBUG
    /// Reset all state (for testing only)
    func reset() {
        lastDataEvent = nil
        authUserID = nil
        playbackState = .idle
        playbackTimeInfo = .zero

        // Finish all streams
        for (_, continuation) in dataEventContinuations {
            continuation.finish()
        }
        for (_, continuation) in authEventContinuations {
            continuation.finish()
        }
        for (_, continuation) in playbackEventContinuations {
            continuation.finish()
        }
        for (_, continuation) in downloadEventContinuations {
            continuation.finish()
        }

        dataEventContinuations.removeAll()
        authEventContinuations.removeAll()
        playbackEventContinuations.removeAll()
        downloadEventContinuations.removeAll()
    }
    #endif
}
