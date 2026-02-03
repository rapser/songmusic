//
//  PlayerUseCases.swift
//  sinkmusic
//
//  Created by Claude Code
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

    // MARK: - State

    private var currentSongID: UUID?
    private var isPlaying: Bool = false

    // MARK: - Initialization

    init(
        audioPlayerRepository: AudioPlayerRepositoryProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.audioPlayerRepository = audioPlayerRepository
        self.songRepository = songRepository
    }

    // MARK: - Playback Control

    /// Reproduce una canción
    func play(songID: UUID) async throws {
        let song = try await songRepository.getByID(songID)
        guard let songEntity = song else {
            throw PlayerError.songNotFound
        }

        guard let localURL = songEntity.localURL else {
            throw PlayerError.fileNotDownloaded
        }

        try await audioPlayerRepository.play(songID: songID, url: localURL)
        currentSongID = songID

        // Incrementar contador de reproducción
        try await songRepository.incrementPlayCount(for: songID)

        // Actualizar Now Playing Info
        await updateNowPlayingInfo(for: songEntity)
    }

    /// Pausa la reproducción
    func pause() async {
        await audioPlayerRepository.pause()
    }

    /// Detiene la reproducción
    func stop() async {
        await audioPlayerRepository.stop()
        currentSongID = nil
    }

    /// Alterna entre play y pause
    func togglePlayPause() async throws {
        if isPlaying {
            await pause()
        } else if let songID = currentSongID {
            try await play(songID: songID)
        }
    }

    /// Busca a una posición específica en la canción
    func seek(to time: TimeInterval) async {
        await audioPlayerRepository.seek(to: time)
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo(for song: Song) async {
        await audioPlayerRepository.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.duration ?? 0,
            currentTime: 0,
            artwork: song.artworkData
        )
    }

    func updateNowPlayingTime(currentTime: TimeInterval, duration: TimeInterval) async {
        guard let songID = currentSongID,
              let songEntity = try? await songRepository.getByID(songID) else {
            return
        }

        await audioPlayerRepository.updateNowPlayingInfo(
            title: songEntity.title,
            artist: songEntity.artist,
            album: songEntity.album,
            duration: duration,
            currentTime: currentTime,
            artwork: songEntity.artworkData
        )
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

    func getIsPlaying() -> Bool {
        return isPlaying
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
