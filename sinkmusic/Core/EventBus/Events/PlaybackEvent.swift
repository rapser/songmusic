//
//  PlaybackEvent.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Core Layer - Event Bus Events
//

import Foundation

/// Eventos de reproducción de audio
/// Emitidos por AudioPlayerService, consumidos por PlayerViewModel
enum PlaybackEvent: Sendable {
    /// Estado de reproducción cambió
    case stateChanged(isPlaying: Bool, songID: UUID?)

    /// Tiempo de reproducción actualizado
    case timeUpdated(current: TimeInterval, duration: TimeInterval)

    /// Canción terminó de reproducirse
    case songFinished(UUID)

    /// Comando remoto recibido (Control Center, AirPods, Live Activity)
    case remoteCommand(RemoteCommand)
}

/// Comandos remotos de reproducción
///
/// `play` y `pause` son intenciones **explícitas e idempotentes**: las envía iOS desde la
/// pantalla de bloqueo / Centro de Control según el estado que él cree que tenemos. Deben
/// honrarse tal cual — nunca traducirse a un toggle, o el espejo con el widget nativo se
/// invierte y ya no se recupera.
///
/// `playPause` queda solo para superficies que sí son un botón de alternar de verdad:
/// el botón central de los AirPods (`togglePlayPauseCommand`) y la Live Activity.
enum RemoteCommand: Sendable, Equatable {
    case play
    case pause
    case playPause
    case next
    case previous
    case seek(TimeInterval)
}

/// Estado actual de reproducción (observable)
enum PlaybackState: Sendable, Equatable {
    /// Sin reproducción activa
    case idle

    /// Reproduciendo canción
    case playing(songID: UUID)

    /// Pausado en canción
    case paused(songID: UUID)
}

/// Información de tiempo de reproducción (observable)
struct PlaybackTimeInfo: Sendable, Equatable {
    let currentTime: TimeInterval
    let duration: TimeInterval

    static let zero = PlaybackTimeInfo(currentTime: 0, duration: 0)
}
