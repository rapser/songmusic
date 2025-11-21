//
//  RefactoredPlayerViewModel.swift
//  sinkmusic
//
//  Created by Refactoring - MVVM + SOLID
//

import Foundation
import Combine
import AVFoundation
import SwiftData

/// ViewModel refactorizado para el reproductor
/// Implementa MVVM correctamente con inyección de dependencias
@MainActor
final class RefactoredPlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentlyPlayingID: UUID?
    @Published var playbackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    @Published var showPlayerView: Bool = false
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var equalizerBands: [EqualizerBand] = EqualizerBand.defaultBands
    @Published var selectedPreset: EqualizerPreset = .flat
    
    enum RepeatMode {
        case off, repeatAll, repeatOne
    }
    
    // MARK: - Dependencies (Protocol-based)
    private let audioPlayer: AudioPlayerProtocol
    private let downloadService: DownloadServiceProtocol
    private let playSongUseCase: PlaySongUseCase
    
    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = []
    
    weak var scrollResetter: ScrollStateResettable?
    
    // MARK: - Initialization with Dependency Injection
    init(
        audioPlayer: AudioPlayerProtocol,
        downloadService: DownloadServiceProtocol,
        metadataService: MetadataServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.audioPlayer = audioPlayer
        self.downloadService = downloadService
        self.playSongUseCase = PlaySongUseCase(
            audioPlayer: audioPlayer,
            downloadService: downloadService,
            metadataService: metadataService,
            songRepository: songRepository
        )
        
        setupSubscriptions()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Suscribirse a cambios de estado
        audioPlayer.onPlaybackStateChanged
            .sink { [weak self] (playing, songID) in
                self?.isPlaying = playing
                self?.currentlyPlayingID = songID
                self?.showPlayerView = songID != nil
            }
            .store(in: &cancellables)
        
        // Suscribirse a cambios de tiempo
        audioPlayer.onPlaybackTimeChanged
            .sink { [weak self] (time, duration) in
                self?.playbackTime = time
                self?.songDuration = duration
            }
            .store(in: &cancellables)
        
        // Suscribirse a finalización de canciones
        audioPlayer.onSongFinished
            .sink { [weak self] finishedSongID in
                self?.handleSongFinished(songID: finishedSongID)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func play(song: Song) {
        print("🎯 RefactoredPlayerViewModel.play() - '\(song.title)'")
        
        if currentlyPlayingID == song.id {
            // Toggle play/pause
            if isPlaying {
                pause()
            } else {
                Task {
                    try? await playSongUseCase.execute(song: song)
                }
            }
        } else {
            // Nueva canción
            currentlyPlayingID = song.id
            Task {
                try? await playSongUseCase.execute(song: song)
            }
        }
        
        scrollResetter?.resetScrollState()
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func stop() {
        audioPlayer.stop()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }
    
    func updateSongsList(_ songs: [Song]) {
        self.allSongs = songs.filter { $0.isDownloaded }
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .repeatAll
        case .repeatAll:
            repeatMode = .repeatOne
        case .repeatOne:
            repeatMode = .off
        }
    }
    
    func playNext(currentSong: Song, allSongs: [Song]) {
        let downloadedSongs = allSongs.filter { $0.isDownloaded }
        guard !downloadedSongs.isEmpty else { return }
        
        if isShuffleEnabled {
            let otherSongs = downloadedSongs.filter { $0.id != currentSong.id }
            if let randomSong = otherSongs.randomElement() {
                play(song: randomSong)
            } else if let firstSong = downloadedSongs.first {
                play(song: firstSong)
            }
        } else {
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let nextIdx = (idx + 1) % downloadedSongs.count
            play(song: downloadedSongs[nextIdx])
        }
    }
    
    func playPrevious(currentSong: Song, allSongs: [Song]) {
        let downloadedSongs = allSongs.filter { $0.isDownloaded }
        guard !downloadedSongs.isEmpty else { return }
        
        if isShuffleEnabled {
            let otherSongs = downloadedSongs.filter { $0.id != currentSong.id }
            if let randomSong = otherSongs.randomElement() {
                play(song: randomSong)
            } else if let firstSong = downloadedSongs.first {
                play(song: firstSong)
            }
        } else {
            guard let idx = downloadedSongs.firstIndex(where: { $0.id == currentSong.id }) else { return }
            let prevIdx = (idx - 1 + downloadedSongs.count) % downloadedSongs.count
            play(song: downloadedSongs[prevIdx])
        }
    }
    
    func updateEqualizer() {
        let gains = equalizerBands.map { Float($0.gain) }
        audioPlayer.updateEqualizer(bands: gains)
    }
    
    func applyPreset(_ preset: EqualizerPreset) {
        selectedPreset = preset
        // Actualizar las bandas con los valores del preset
        let gains = preset.gains
        for (index, gain) in gains.enumerated() where index < equalizerBands.count {
            equalizerBands[index].gain = gain
        }
        updateEqualizer()
    }
    
    // MARK: - Private Methods
    private func handleSongFinished(songID: UUID) {
        guard let currentSong = allSongs.first(where: { $0.id == songID }) else { return }
        
        switch repeatMode {
        case .repeatOne:
            play(song: currentSong)
        case .repeatAll:
            playNext(currentSong: currentSong, allSongs: allSongs)
        case .off:
            if isShuffleEnabled {
                playNext(currentSong: currentSong, allSongs: allSongs)
            } else {
                let downloadedSongs = allSongs.filter { $0.isDownloaded }
                if let idx = downloadedSongs.firstIndex(where: { $0.id == songID }),
                   idx < downloadedSongs.count - 1 {
                    playNext(currentSong: currentSong, allSongs: allSongs)
                }
            }
        }
    }
}
