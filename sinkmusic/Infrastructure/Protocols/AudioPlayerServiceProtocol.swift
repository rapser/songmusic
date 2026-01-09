//
//  AudioPlayerServiceProtocol.swift
//  sinkmusic
//
//  Created by Claude Code - Clean Architecture
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de reproducción de audio
/// Permite mockear AudioPlayerService para testing
protocol AudioPlayerServiceProtocol: Sendable {

    // MARK: - Playback Control

    /// Reproduce una canción desde una URL
    func play(songID: UUID, url: URL)

    /// Pausa la reproducción actual
    func pause()

    /// Detiene la reproducción completamente
    func stop()

    /// Busca a una posición específica en la canción
    func seek(to time: TimeInterval)

    /// Verifica si está reproduciendo actualmente
    var isPlaying: Bool { get }

    // MARK: - Equalizer

    /// Actualiza las bandas del ecualizador
    func updateEqualizer(bands: [Float])

    // MARK: - Now Playing Info

    /// Actualiza la información de Now Playing (Lock Screen, CarPlay)
    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        artwork: Data?
    )

    // MARK: - Callbacks

    /// Callback cuando cambia el estado de reproducción
    var onPlaybackStateChanged: (@MainActor (Bool, UUID?) -> Void)? { get set }

    /// Callback cuando cambia el tiempo de reproducción
    var onPlaybackTimeChanged: (@MainActor (TimeInterval, TimeInterval) -> Void)? { get set }

    /// Callback cuando termina una canción
    var onSongFinished: (@MainActor (UUID) -> Void)? { get set }

    /// Callbacks para controles remotos
    var onRemotePlayPause: (@MainActor () -> Void)? { get set }
    var onRemoteNext: (@MainActor () -> Void)? { get set }
    var onRemotePrevious: (@MainActor () -> Void)? { get set }
}
