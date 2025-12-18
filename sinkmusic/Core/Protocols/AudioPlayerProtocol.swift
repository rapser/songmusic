//
//  AudioPlayerProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

/// Protocolo que define las capacidades del reproductor de audio
/// Cumple con Dependency Inversion Principle (SOLID)
protocol AudioPlayerProtocol {
    /// Callback que se ejecuta cuando cambia el estado de reproducción
    var onPlaybackStateChanged: (@MainActor (Bool, UUID?) -> Void)? { get set }

    /// Callback que se ejecuta cuando se actualiza el tiempo de reproducción
    var onPlaybackTimeChanged: (@MainActor (TimeInterval, TimeInterval) -> Void)? { get set }

    /// Callback que se ejecuta cuando una canción termina
    var onSongFinished: (@MainActor (UUID) -> Void)? { get set }
    
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

// MARK: - Extensión con métodos avanzados de audio (opcionales)

extension AudioPlayerProtocol {
    /// Ajusta la amplitud del estéreo (0.0 = mono, 1.0 = muy ancho)
    /// - Parameter width: Valor entre 0.0 y 1.5 (recomendado: 0.5-0.8)
    func setStereoWidth(_ width: Float) { }

    /// Activa/desactiva el boost de graves
    /// - Parameter enabled: true para activar, false para desactivar
    func setBassBoost(_ enabled: Bool) { }

    /// Activa/desactiva el boost de agudos
    /// - Parameter enabled: true para activar, false para desactivar
    func setTrebleBoost(_ enabled: Bool) { }

    /// Ajusta la intensidad de la compresión dinámica
    /// - Parameter intensity: Valor entre 0.0 (sin compresión) y 1.0 (máxima)
    func setCompression(_ intensity: Float) { }
}
