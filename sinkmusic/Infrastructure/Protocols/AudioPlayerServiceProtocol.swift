//
//  AudioPlayerServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de reproducción de audio
/// Permite mockear AudioPlayerService para testing
/// Nota: Los eventos se emiten via EventBus (no callbacks)
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
}
