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

    /// Carga y reproduce una canción, opcionalmente desde una posición dada
    func play(songID: UUID, url: URL, startTime: TimeInterval) async throws

    /// Continúa la canción ya cargada sin reprogramarla ni reiniciar su posición.
    /// Devuelve `false` si no hay nada cargado y hace falta un `play` real.
    func resume() async -> Bool

    /// Pausa la reproducción
    func pause() async

    /// Detiene la reproducción
    func stop() async

    /// Busca a una posición específica
    func seek(to time: TimeInterval) async

    /// Estado real de reproducción — fuente única de verdad, leída del motor de audio
    func isPlaying() async -> Bool

    // MARK: - Equalizer

    /// Actualiza el ecualizador
    func updateEqualizer(bands: [Float]) async

    // MARK: - Now Playing Info

    /// Fija la metadata de la canción actual (Lock Screen), una vez por canción
    func setNowPlayingMetadata(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artwork: Data?
    ) async

    /// Refresca solo el tiempo transcurrido (Lock Screen)
    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?) async
}
