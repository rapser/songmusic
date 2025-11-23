//
//  AudioEngineManager.swift
//  sinkmusic
//
//  Created by Refactoring - Single Responsibility Principle
//

import Foundation
import AVFoundation

/// Maneja el motor de audio y sus nodos
/// Responsabilidad única: configuración y gestión del AVAudioEngine
final class AudioEngineManager {
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let eq: AVAudioUnitEQ
    private var isFirstConnection = true
    
    var isRunning: Bool {
        audioEngine.isRunning
    }
    
    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        self.eq = AVAudioUnitEQ(numberOfBands: 10)
        
        setupNodes()
        configureEqualizer()
    }
    
    // MARK: - Setup
    
    private func setupNodes() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)
    }
    
    private func configureEqualizer() {
        let frequencies: [Float] = [60, 150, 400, 1000, 2400, 3500, 6000, 10000, 15000, 20000]
        
        for (index, frequency) in frequencies.enumerated() where index < eq.bands.count {
            eq.bands[index].filterType = .parametric
            eq.bands[index].frequency = frequency
            eq.bands[index].bandwidth = 1.0
            eq.bands[index].gain = 0.0
            eq.bands[index].bypass = false
        }
    }
    
    // MARK: - Public Methods
    
    func getPlayerNode() -> AVAudioPlayerNode {
        playerNode
    }
    
    func connectNodes(with format: AVAudioFormat) throws {
        if !isFirstConnection {
            playerNode.reset()
            
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            
            audioEngine.disconnectNodeInput(playerNode)
            audioEngine.disconnectNodeInput(eq)
        } else {
            isFirstConnection = false
        }
        
        audioEngine.connect(playerNode, to: eq, format: format)
        audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: format)
        
        audioEngine.prepare()
    }
    
    func start() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    func updateEqualizer(bands: [Float]) {
        guard bands.count <= eq.bands.count else { return }
        
        for (index, gain) in bands.enumerated() {
            eq.bands[index].gain = gain
        }
    }
}
