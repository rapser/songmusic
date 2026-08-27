//
//  PlaybackStateRepositoryProtocol.swift
//  sinkmusic
//
//  Clean Architecture - Domain Layer
//

import Foundation

/// Protocolo de repositorio para persistir la última posición de reproducción.
/// Permite restaurar la canción y el minuto exacto donde el usuario dejó de escuchar
/// aunque la app se haya cerrado por completo.
protocol PlaybackStateRepositoryProtocol: Sendable {

    /// Guarda la canción y el tiempo actual de reproducción
    func save(songID: UUID, time: TimeInterval)

    /// Recupera la última canción y tiempo guardados, si existen
    func load() -> (songID: UUID, time: TimeInterval)?

    /// Elimina el estado de reproducción persistido
    func clear()
}
