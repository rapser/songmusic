//
//  AudioPlayerProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

// MARK: - ISP: Interface Segregation Principle
// Los protocolos están segregados por responsabilidad específica

/// Protocolo básico de reproducción de audio
/// SOLID: Interface Segregation - Solo métodos de playback básico
protocol AudioPlaybackProtocol {
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
}

/// Protocolo para callbacks de estado de reproducción
/// SOLID: Interface Segregation - Solo callbacks de estado
protocol AudioPlaybackStateProtocol {
    /// Callback que se ejecuta cuando cambia el estado de reproducción
    var onPlaybackStateChanged: (@MainActor (Bool, UUID?) -> Void)? { get set }

    /// Callback que se ejecuta cuando se actualiza el tiempo de reproducción
    var onPlaybackTimeChanged: (@MainActor (TimeInterval, TimeInterval) -> Void)? { get set }

    /// Callback que se ejecuta cuando una canción termina
    var onSongFinished: (@MainActor (UUID) -> Void)? { get set }
}

/// Protocolo para controles remotos (CarPlay, Lock Screen, etc.)
/// SOLID: Interface Segregation - Solo callbacks remotos
protocol RemoteControlsProtocol {
    /// Callback para play/pause desde controles remotos
    var onRemotePlayPause: (@MainActor () -> Void)? { get set }

    /// Callback para siguiente canción desde controles remotos
    var onRemoteNext: (@MainActor () -> Void)? { get set }

    /// Callback para canción anterior desde controles remotos
    var onRemotePrevious: (@MainActor () -> Void)? { get set }
}

/// Protocolo para control del ecualizador
/// SOLID: Interface Segregation - Solo funciones de ecualizador
protocol AudioEqualizerProtocol {
    /// Actualiza las bandas del ecualizador
    /// - Parameter bands: Array con los valores de ganancia de cada banda
    func updateEqualizer(bands: [Float])
}

/// Protocolo completo del reproductor de audio
/// SOLID: Interface Segregation - Composición de protocolos específicos
/// Cumple con Dependency Inversion Principle (SOLID)
protocol AudioPlayerProtocol: AudioPlaybackProtocol, AudioPlaybackStateProtocol, RemoteControlsProtocol, AudioEqualizerProtocol {
    // Este protocolo hereda todos los métodos y propiedades de los protocolos base
    // Los clientes pueden depender solo del protocolo específico que necesiten
}

// MARK: - Extensión con métodos avanzados de audio (opcionales)

extension AudioPlayerProtocol {
    /// Actualiza la información de Now Playing en el sistema
    /// - Parameters:
    ///   - title: Título de la canción
    ///   - artist: Artista
    ///   - album: Álbum (opcional)
    ///   - duration: Duración total
    ///   - currentTime: Tiempo actual de reproducción
    ///   - artwork: Datos de la imagen del artwork (opcional)
    func updateNowPlayingInfo(title: String, artist: String, album: String?, duration: TimeInterval, currentTime: TimeInterval, artwork: Data?) { }

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
