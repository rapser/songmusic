//
//  PlayerUseCases.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Domain Layer
//

import Foundation

/// Casos de uso agrupados para el reproductor de audio
/// Coordina la lógica de negocio relacionada con reproducción
@MainActor
final class PlayerUseCases {

    // MARK: - Dependencies

    private let audioPlayerRepository: AudioPlayerRepositoryProtocol
    private let songRepository: SongRepositoryProtocol
    private let playbackStateRepository: PlaybackStateRepositoryProtocol
    private let fileStore: DownloadFileStoreProtocol

    // MARK: - State

    private var currentSongID: UUID?
    private var currentSong: Song?

    /// Tiempo desde el que reanudar la próxima vez que se llame a `play`/`togglePlayPause`.
    /// Se fija al restaurar el estado persistido y se consume en la primera reproducción.
    private var pendingResumeTime: TimeInterval?

    // Nota: aquí NO se cachea `isPlaying`. El estado real vive en el motor de audio y se
    // consulta con `isPlaying()`. Tener una copia local provocaba que, al escribirse después
    // de un `await`, pisara el valor de una operación concurrente y el reproductor nativo
    // quedara desincronizado con el de la app.

    // MARK: - Initialization

    init(
        audioPlayerRepository: AudioPlayerRepositoryProtocol,
        songRepository: SongRepositoryProtocol,
        playbackStateRepository: PlaybackStateRepositoryProtocol,
        fileStore: DownloadFileStoreProtocol
    ) {
        self.audioPlayerRepository = audioPlayerRepository
        self.songRepository = songRepository
        self.playbackStateRepository = playbackStateRepository
        self.fileStore = fileStore
    }

    // MARK: - Playback Control

    /// Carga y reproduce una canción, opcionalmente desde un tiempo específico.
    ///
    /// Siempre cuenta como una reproducción nueva. Para continuar la canción en curso
    /// usa `resume()`, que no reinicia la posición ni vuelve a contar.
    func play(songID: UUID, startTime: TimeInterval = 0) async throws {
        let song = try await songRepository.getByID(songID)
        guard let songEntity = song else {
            throw PlayerError.songNotFound
        }

        guard songEntity.isDownloaded, let localURL = fileStore.existingFileURL(for: songID) else {
            throw PlayerError.fileNotDownloaded
        }

        // Metadata primero: así el push de Now Playing que hace el servicio al arrancar
        // ya lleva título y artwork, sin un frame en blanco en la pantalla de bloqueo.
        await audioPlayerRepository.setNowPlayingMetadata(
            title: songEntity.title,
            artist: songEntity.artist,
            album: songEntity.album,
            duration: songEntity.duration ?? 0,
            artwork: songEntity.artworkData
        )

        try await audioPlayerRepository.play(songID: songID, url: localURL, startTime: startTime)

        currentSongID = songID
        currentSong = songEntity
        pendingResumeTime = nil

        playbackStateRepository.save(songID: songID, time: startTime)

        try await songRepository.incrementPlayCount(for: songID)
    }

    /// Continúa la reproducción de la canción actual.
    ///
    /// Si el motor todavía tiene la pista cargada, la reanuda tal cual. Si no (arranque en
    /// frío tras `restoreLastPlaybackState`), hace una reproducción real desde la posición
    /// guardada. Es idempotente: llamarlo estando ya reproduciendo no hace nada.
    func resume() async throws {
        if await audioPlayerRepository.resume() {
            pendingResumeTime = nil
            return
        }

        // El motor no tiene nada cargado: hace falta un play real desde donde se quedó.
        guard let songID = currentSongID else { return }
        try await play(songID: songID, startTime: pendingResumeTime ?? 0)
    }

    /// Pausa la reproducción
    func pause() async {
        await audioPlayerRepository.pause()
    }

    /// Detiene la reproducción
    func stop() async {
        await audioPlayerRepository.stop()
        currentSongID = nil
        currentSong = nil
    }

    /// Alterna entre play y pause consultando el estado real del motor de audio
    func togglePlayPause() async throws {
        if await audioPlayerRepository.isPlaying() {
            await pause()
        } else {
            try await resume()
        }
    }

    /// Busca a una posición específica en la canción
    func seek(to time: TimeInterval) async {
        await audioPlayerRepository.seek(to: time)
    }

    // MARK: - Playback State Persistence

    /// Guarda el avance de la canción en curso, para poder retomarla al reabrir la app.
    ///
    /// Ya no toca Now Playing: de eso se encarga `AudioPlayerService`, que es quien conoce
    /// el estado real y lo empuja en cada transición. Se llama periódicamente mientras suena
    /// y también de inmediato al pausar o al pasar la app a segundo plano, momentos en los
    /// que ya no llegan `timeUpdated`.
    func persistCurrentPlaybackTime(_ time: TimeInterval) {
        guard let songEntity = currentSong else { return }
        playbackStateRepository.save(songID: songEntity.id, time: time)
    }

    /// Restaura la última canción escuchada y el minuto donde se dejó de reproducir.
    /// No inicia la reproducción: solo prepara el estado para que la UI muestre el
    /// mini reproductor y para que la próxima llamada a `togglePlayPause` retome desde ahí.
    func restoreLastPlaybackState() async -> (song: Song, time: TimeInterval)? {
        guard let saved = playbackStateRepository.load() else { return nil }

        guard let songEntity = try? await songRepository.getByID(saved.songID),
              songEntity.isDownloaded else {
            playbackStateRepository.clear()
            return nil
        }

        currentSongID = songEntity.id
        currentSong = songEntity
        pendingResumeTime = saved.time

        return (songEntity, saved.time)
    }

    // MARK: - Song Access

    /// Obtiene una canción por ID (para acceso desde ViewModel)
    func getSongByID(_ id: UUID) async throws -> Song? {
        return try await songRepository.getByID(id)
    }

    /// Obtiene múltiples canciones por IDs
    func getSongsByIDs(_ ids: [UUID]) async throws -> [Song] {
        var songs: [Song] = []
        for id in ids {
            if let song = try await songRepository.getByID(id) {
                songs.append(song)
            }
        }
        return songs
    }

    // MARK: - Getters

    func getCurrentSongID() -> UUID? {
        return currentSongID
    }

    /// Estado real de reproducción, consultado al motor de audio (nunca cacheado aquí)
    func isPlaying() async -> Bool {
        await audioPlayerRepository.isPlaying()
    }
}

// MARK: - Errors

enum PlayerError: Error {
    case songNotFound
    case fileNotDownloaded
    case playbackFailed
}

// MARK: - Sendable Conformance

extension PlayerUseCases: Sendable {}
