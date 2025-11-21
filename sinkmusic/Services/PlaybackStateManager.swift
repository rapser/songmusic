//
//  PlaybackStateManager.swift
//  sinkmusic
//
//  Created by Refactoring - Single Responsibility Principle
//

import Foundation
import AVFoundation
import Combine

/// Maneja el estado de reproducción y el timer de progreso
/// Responsabilidad única: gestión del estado de playback
final class PlaybackStateManager {
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?
    private var currentScheduleID = UUID()
    
    let onPlaybackStateChanged = PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never>()
    let onPlaybackTimeChanged = PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never>()
    let onSongFinished = PassthroughSubject<UUID, Never>()
    
    func getCurrentSongID() -> UUID? {
        currentlyPlayingID
    }
    
    func setCurrentSongID(_ id: UUID?) {
        currentlyPlayingID = id
    }
    
    func generateNewScheduleID() -> UUID {
        let newID = UUID()
        currentScheduleID = newID
        return newID
    }
    
    func isValidScheduleID(_ id: UUID) -> Bool {
        currentScheduleID == id
    }
    
    func startPlaybackTimer(playerNode: AVAudioPlayerNode, audioFile: AVAudioFile) {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let nodeTime = playerNode.lastRenderTime,
                  let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return
            }
            
            let currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            
            self.onPlaybackTimeChanged.send((time: currentTime, duration: duration))
        }
    }
    
    func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func notifyPlaybackStateChanged(isPlaying: Bool, songID: UUID?) {
        onPlaybackStateChanged.send((isPlaying: isPlaying, songID: songID))
    }
    
    func notifySongFinished(songID: UUID) {
        stopPlaybackTimer()
        onSongFinished.send(songID)
    }
}
