//
//  AudioPlayerProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

// MARK: - ISP: Interface Segregation Principle
// Los protocolos están segregados por responsabilidad específica
// Nota: Los eventos se emiten via EventBus (no callbacks)

/// Protocolo básico de reproducción de audio
/// SOLID: Interface Segregation - Solo métodos de playback básico
@MainActor
protocol AudioPlaybackProtocol {
    /// Carga y reproduce una canción desde una URL
    /// - Parameters:
    ///   - songID: Identificador único de la canción
    ///   - url: URL local del archivo de audio
    ///   - startTime: Posición inicial en segundos (0 = desde el principio)
    func play(songID: UUID, url: URL, startTime: TimeInterval)

    /// Continúa la canción ya cargada sin reprogramarla ni reiniciar su posición
    /// - Returns: `false` si no hay ninguna pista cargada y hace falta un `play` real
    @discardableResult
    func resume() -> Bool

    /// Pausa la reproducción actual
    func pause()

    /// Detiene completamente la reproducción
    func stop()

    /// Busca una posición específica en la canción
    /// - Parameter time: Tiempo en segundos
    func seek(to time: TimeInterval)
}

extension AudioPlaybackProtocol {
    /// Conveniencia para reproducir desde el inicio
    func play(songID: UUID, url: URL) {
        play(songID: songID, url: url, startTime: 0)
    }
}

/// Protocolo para control del ecualizador
/// SOLID: Interface Segregation - Solo funciones de ecualizador
@MainActor
protocol AudioEqualizerProtocol {
    /// Actualiza las bandas del ecualizador
    /// - Parameter bands: Array con los valores de ganancia de cada banda
    func updateEqualizer(bands: [Float])
}

/// Protocolo completo del reproductor de audio
/// SOLID: Interface Segregation - Composición de protocolos específicos
/// Cumple con Dependency Inversion Principle (SOLID)
/// Nota: Los eventos de estado y controles remotos se emiten via EventBus
@MainActor
protocol AudioPlayerProtocol: AudioPlaybackProtocol, AudioEqualizerProtocol {
    /// Fija la metadata de la canción actual en Now Playing (una vez por canción)
    /// - Parameters:
    ///   - title: Título de la canción
    ///   - artist: Artista
    ///   - album: Álbum (opcional)
    ///   - duration: Duración total
    ///   - artwork: Datos de la imagen del artwork (opcional)
    func setNowPlayingMetadata(title: String, artist: String, album: String?, duration: TimeInterval, artwork: Data?)

    /// Refresca solo el tiempo transcurrido de Now Playing
    /// - Parameters:
    ///   - elapsed: Tiempo actual de reproducción
    ///   - duration: Duración total, si se conoce
    func updateNowPlayingTime(_ elapsed: TimeInterval, duration: TimeInterval?)
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
