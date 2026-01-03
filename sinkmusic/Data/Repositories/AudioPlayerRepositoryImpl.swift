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

    private let audioPlayerService: AudioPlayerService

    // MARK: - Initialization

    init(audioPlayerService: AudioPlayerService) {
        self.audioPlayerService = audioPlayerService
    }

    // MARK: - AudioPlayerRepositoryProtocol

    func play(songID: UUID, url: URL) async {
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

    // MARK: - State Observation

    func observePlaybackState(onChange: @escaping @MainActor (Bool, UUID?) -> Void) {
        audioPlayerService.onPlaybackStateChanged = onChange
    }

    func observePlaybackTime(onChange: @escaping @MainActor (TimeInterval, TimeInterval) -> Void) {
        audioPlayerService.onPlaybackTimeChanged = onChange
    }

    func observeSongFinished(onFinish: @escaping @MainActor (UUID) -> Void) {
        audioPlayerService.onSongFinished = onFinish
    }

    // MARK: - Remote Controls

    func observeRemotePlayPause(onCommand: @escaping @MainActor () -> Void) {
        audioPlayerService.onRemotePlayPause = onCommand
    }

    func observeRemoteNext(onCommand: @escaping @MainActor () -> Void) {
        audioPlayerService.onRemoteNext = onCommand
    }

    func observeRemotePrevious(onCommand: @escaping @MainActor () -> Void) {
        audioPlayerService.onRemotePrevious = onCommand
    }
}

// MARK: - Sendable Conformance

extension AudioPlayerRepositoryImpl: Sendable {}
