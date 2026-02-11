//
//  AudioPlayerRepositoryProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Protocolo de repositorio para el reproductor de audio
/// Abstrae el AudioPlayerService de la capa de dominio
/// Nota: Los eventos se emiten via EventBus (no callbacks)
protocol AudioPlayerRepositoryProtocol: Sendable {

    // MARK: - Playback Control

    /// Reproduce una canción
    func play(songID: UUID, url: URL) async throws

    /// Pausa la reproducción
    func pause() async

    /// Detiene la reproducción
    func stop() async

    /// Busca a una posición específica
    func seek(to time: TimeInterval) async

    /// Verifica si está reproduciendo
    func isPlaying() async -> Bool

    // MARK: - Equalizer

    /// Actualiza el ecualizador
    func updateEqualizer(bands: [Float]) async

    // MARK: - Now Playing Info

    /// Actualiza la información de reproducción (Lock Screen, CarPlay)
    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        artwork: Data?
    ) async
}
