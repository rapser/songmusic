//
//  EventBusProtocol.swift
//  sinkmusic
//
//  Created by Claude Code
//  Core Layer - Protocol for Dependency Inversion
//

import Foundation

/// Protocolo que define el contrato del EventBus
///
/// SOLID: Dependency Inversion Principle
/// - Las capas dependen de esta abstracción, no de EventBus concreto
/// - Permite inyección de dependencias y testing con mocks
///
/// ## Uso en ViewModels
/// ```swift
/// final class MyViewModel {
///     private let eventBus: EventBusProtocol
///
///     init(eventBus: EventBusProtocol) {
///         self.eventBus = eventBus
///     }
/// }
/// ```
@MainActor
protocol EventBusProtocol: AnyObject, Sendable {

    // MARK: - Observable State (read-only)

    /// Último evento de datos emitido
    var lastDataEvent: DataChangeEvent? { get }

    /// ID del usuario autenticado (nil si no hay sesión)
    var authUserID: String? { get }

    /// Indica si hay un usuario autenticado
    var isAuthenticated: Bool { get }

    /// Estado actual de reproducción
    var playbackState: PlaybackState { get }

    /// Información de tiempo de reproducción
    var playbackTimeInfo: PlaybackTimeInfo { get }

    // MARK: - Emit Events

    /// Emitir evento de cambio de datos
    func emit(_ event: DataChangeEvent)

    /// Emitir evento de autenticación
    func emit(_ event: AuthEvent)

    /// Emitir evento de reproducción
    func emit(_ event: PlaybackEvent)

    /// Emitir evento de descarga
    func emit(_ event: DownloadEvent)

    // MARK: - AsyncStream Factories

    /// Stream de eventos de datos
    func dataEvents() -> AsyncStream<DataChangeEvent>

    /// Stream de eventos de autenticación
    func authEvents() -> AsyncStream<AuthEvent>

    /// Stream de eventos de reproducción
    func playbackEvents() -> AsyncStream<PlaybackEvent>

    /// Stream de eventos de descarga
    func downloadEvents() -> AsyncStream<DownloadEvent>
}
