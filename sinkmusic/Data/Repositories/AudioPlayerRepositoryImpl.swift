//
//  AudioPlayerRepositoryImpl.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Audio Player
/// Encapsula el AudioPlayerService y adapta su interfaz al dominio
@MainActor
final class AudioPlayerRepositoryImpl: AudioPlayerRepositoryProtocol {

    // MARK: - Dependencies

    private var audioPlayerService: AudioPlayerServiceProtocol

    // MARK: - Callbacks

    var onPlaybackStateChanged: (@MainActor (Bool, UUID?) -> Void)? {
        get { audioPlayerService.onPlaybackStateChanged }
        set { audioPlayerService.onPlaybackStateChanged = newValue }
    }

    var onPlaybackTimeChanged: (@MainActor (TimeInterval, TimeInterval) -> Void)? {
        get { audioPlayerService.onPlaybackTimeChanged }
        set { audioPlayerService.onPlaybackTimeChanged = newValue }
    }

    var onSongFinished: (@MainActor (UUID) -> Void)? {
        get { audioPlayerService.onSongFinished }
        set { audioPlayerService.onSongFinished = newValue }
    }

    var onRemotePlayPause: (@MainActor () -> Void)? {
        get { audioPlayerService.onRemotePlayPause }
        set { audioPlayerService.onRemotePlayPause = newValue }
    }

    var onRemoteNext: (@MainActor () -> Void)? {
        get { audioPlayerService.onRemoteNext }
        set { audioPlayerService.onRemoteNext = newValue }
    }

    var onRemotePrevious: (@MainActor () -> Void)? {
        get { audioPlayerService.onRemotePrevious }
        set { audioPlayerService.onRemotePrevious = newValue }
    }

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
