//
//  LiveActivityServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de Live Activities (Dynamic Island)
/// Permite mockear LiveActivityService para testing
@MainActor
protocol LiveActivityServiceProtocol: Sendable {

    // MARK: - Activity Management

    /// Inicia una Live Activity para la canción actual
    func startActivity(
        songID: UUID,
        songTitle: String,
        artistName: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        artworkThumbnail: Data?
    )

    /// Actualiza el estado de la Live Activity actual
    func updateActivity(
        songTitle: String,
        artistName: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        artworkThumbnail: Data?
    )

    /// Finaliza la Live Activity actual
    func endActivity()

    /// Verifica si hay una Live Activity activa
    var hasActiveActivity: Bool { get }
}
