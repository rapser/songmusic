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
@MainActor
protocol AudioPlayerServiceProtocol: Sendable {

    // MARK: - Playback Control

    /// Carga y reproduce una canción desde una URL, opcionalmente desde una posición dada
    func play(songID: UUID, url: URL, startTime: TimeInterval)

    /// Continúa la canción ya cargada sin reprogramarla ni reiniciar su posición.
    /// Devuelve `false` si no hay nada cargado y hace falta un `play` real.
    @discardableResult
    func resume() -> Bool

    /// Pausa la reproducción actual
    func pause()

    /// Detiene la reproducción completamente
    func stop()

    /// Busca a una posición específica en la canción
    func seek(to time: TimeInterval)

    /// Estado real de reproducción — **fuente única de verdad de toda la app**.
    /// Ninguna capa superior debe cachear su propia copia de este valor.
    var isPlaying: Bool { get }

    // MARK: - Equalizer

    /// Actualiza las bandas del ecualizador
    func updateEqualizer(bands: [Float])

    // MARK: - Now Playing Info

    /// Fija la metadata de la canción actual en Now Playing (una vez por canción)
    func setNowPlayingMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?
    )

    /// Refresca solo el tiempo transcurrido de Now Playing
    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?)
}
