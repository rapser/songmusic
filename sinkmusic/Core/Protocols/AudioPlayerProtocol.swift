//
//  AudioPlayerProtocol.swift
//  sinkmusic
//
//  Created by Refactoring - SOLID Principles
//

import Foundation
import Combine

/// Protocolo que define las capacidades del reproductor de audio
/// Cumple con Dependency Inversion Principle (SOLID)
protocol AudioPlayerProtocol {
    /// Publisher que emite cambios en el estado de reproducción
    var onPlaybackStateChanged: PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never> { get }
    
    /// Publisher que emite actualizaciones del tiempo de reproducción
    var onPlaybackTimeChanged: PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never> { get }
    
    /// Publisher que emite cuando una canción termina
    var onSongFinished: PassthroughSubject<UUID, Never> { get }
    
    /// Reproduce una canción desde una URL
    /// - Parameters:
    ///   - songID: Identificador único de la canción
    ///   - url: URL local del archivo de audio
    func play(songID: UUID, url: URL)
    
    /// Pausa la reproducción actual
    func pause()
    
    /// Detiene completamente la reproducción
    func stop()
    
    /// Busca una posición específica en la canción
    /// - Parameter time: Tiempo en segundos
    func seek(to time: TimeInterval)
    
    /// Actualiza las bandas del ecualizador
    /// - Parameter bands: Array con los valores de ganancia de cada banda
    func updateEqualizer(bands: [Float])
}
