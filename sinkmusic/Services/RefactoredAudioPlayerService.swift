//
//  RefactoredAudioPlayerService.swift
//  sinkmusic
//
//  Created by Refactoring - SOLID Principles
//

import Foundation
import AVFoundation
import Combine

/// Servicio de reproducción de audio refactorizado
/// Implementa AudioPlayerProtocol y cumple con Single Responsibility Principle
/// Delega responsabilidades específicas a managers dedicados
final class RefactoredAudioPlayerService: NSObject, AudioPlayerProtocol {
    
    // MARK: - Publishers (Protocolo)
    var onPlaybackStateChanged: PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never> {
        stateManager.onPlaybackStateChanged
    }
    
    var onPlaybackTimeChanged: PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never> {
        stateManager.onPlaybackTimeChanged
    }
    
    var onSongFinished: PassthroughSubject<UUID, Never> {
        stateManager.onSongFinished
    }
    
    // MARK: - Dependencies
    private let engineManager: AudioEngineManager
    private let stateManager: PlaybackStateManager
    private var audioFile: AVAudioFile?
    
    // MARK: - Initialization
    override init() {
        self.engineManager = AudioEngineManager()
        self.stateManager = PlaybackStateManager()
        super.init()
        setupAudioSession()
    }
    
    // Inicializador con inyección de dependencias para testing
    init(engineManager: AudioEngineManager, stateManager: PlaybackStateManager) {
        self.engineManager = engineManager
        self.stateManager = stateManager
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }
    
    // MARK: - AudioPlayerProtocol Implementation
    func play(songID: UUID, url: URL) {
        let playerNode = engineManager.getPlayerNode()
        
        // Si es la misma canción, simplemente reanuda
        if stateManager.getCurrentSongID() == songID {
            if !playerNode.isPlaying {
                playerNode.play()
                try? engineManager.start()
                
                if let audioFile = audioFile {
                    stateManager.startPlaybackTimer(playerNode: playerNode, audioFile: audioFile)
                }
                stateManager.notifyPlaybackStateChanged(isPlaying: true, songID: songID)
            }
            return
        }
        
        // Es una canción nueva
        do {
            // Cargar archivo de audio
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile = audioFile else {
                return
            }
            
            // Conectar nodos con el formato correcto
            try engineManager.connectNodes(with: audioFile.processingFormat)
            
            // Generar nuevo schedule ID y programar reproducción
            let scheduleID = stateManager.generateNewScheduleID()
            
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // Verificar si este completion handler es válido
                    guard self.stateManager.isValidScheduleID(scheduleID),
                          let currentID = self.stateManager.getCurrentSongID() else {
                        return
                    }
                    
                    self.stateManager.notifySongFinished(songID: currentID)
                }
            }
            
            // Iniciar engine
            try engineManager.start()
            
            // Reproducir
            playerNode.play()
            
            // Actualizar estado
            stateManager.setCurrentSongID(songID)
            stateManager.startPlaybackTimer(playerNode: playerNode, audioFile: audioFile)
            stateManager.notifyPlaybackStateChanged(isPlaying: true, songID: songID)
            
        } catch {
            stateManager.notifyPlaybackStateChanged(isPlaying: false, songID: nil)
        }
    }
    
    func pause() {
        let playerNode = engineManager.getPlayerNode()
        playerNode.pause()
        stateManager.stopPlaybackTimer()
        stateManager.notifyPlaybackStateChanged(isPlaying: false, songID: stateManager.getCurrentSongID())
    }
    
    func stop() {
        let playerNode = engineManager.getPlayerNode()
        playerNode.stop()
        engineManager.stop()
        
        let oldID = stateManager.getCurrentSongID()
        stateManager.setCurrentSongID(nil)
        stateManager.stopPlaybackTimer()
        audioFile = nil
        
        stateManager.notifyPlaybackStateChanged(isPlaying: false, songID: oldID)
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let playerNode = engineManager.getPlayerNode()
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        
        playerNode.stop()
        
        if startFrame < audioFile.length {
            let frameCount = AVAudioFrameCount(audioFile.length - startFrame)
            
            playerNode.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: nil
            ) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self,
                          let currentID = self.stateManager.getCurrentSongID() else { return }
                    
                    self.stateManager.notifySongFinished(songID: currentID)
                }
            }
            
            playerNode.play()
        }
    }
    
    func updateEqualizer(bands: [Float]) {
        engineManager.updateEqualizer(bands: bands)
    }
}
