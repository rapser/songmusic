//
//  AudioPlayerRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Audio Player
/// Encapsula el AudioPlayerService y adapta su interfaz al dominio
/// Nota: Los eventos se emiten directamente desde AudioPlayerService via EventBus
@MainActor
final class AudioPlayerRepositoryImpl: AudioPlayerRepositoryProtocol {

    // MARK: - Dependencies

    private let audioPlayerService: AudioPlayerServiceProtocol

    // MARK: - Initialization

    init(audioPlayerService: AudioPlayerServiceProtocol) {
        self.audioPlayerService = audioPlayerService
    }

    // MARK: - AudioPlayerRepositoryProtocol

    func play(songID: UUID, url: URL) async throws {
        audioPlayerService.play(songID: songID, url: url)
    }

    func pause() async {
        audioPlayerService.pause()
    }

    func stop() async {
        audioPlayerService.stop()
    }

    func seek(to time: TimeInterval) async {
        audioPlayerService.seek(to: time)
    }

    func isPlaying() async -> Bool {
        return audioPlayerService.isPlaying
    }

    func updateEqualizer(bands: [Float]) async {
        audioPlayerService.updateEqualizer(bands: bands)
    }

    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        artwork: Data?
    ) async {
        audioPlayerService.updateNowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            currentTime: currentTime,
            artwork: artwork
        )
    }
}

// MARK: - Sendable Conformance

extension AudioPlayerRepositoryImpl: Sendable {}
