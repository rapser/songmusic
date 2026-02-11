//
//  Playlist.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Entidad de dominio PURA - Sin dependencia de SwiftData
/// Representa una playlist en la lógica de negocio
struct Playlist: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let createdAt: Date
    let updatedAt: Date
    let coverImageData: Data?
    let songs: [Song]

    // MARK: - Computed Properties (Lógica de Dominio)

    /// Número total de canciones en la playlist
    var songCount: Int {
        songs.count
    }

    /// Duración total de todas las canciones
    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    /// Duración formateada (ej: "2 h 35 min" o "45 min")
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours) h \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }

    /// Información para mostrar en UI (ej: "15 canciones • 1 h 20 min")
    var displayInfo: String {
        let songsText = songCount == 1 ? "1 canción" : "\(songCount) canciones"
        return "\(songsText) • \(formattedDuration)"
    }

    /// Indica si la playlist está vacía
    var isEmpty: Bool {
        songs.isEmpty
    }

    /// Canciones descargadas en la playlist
    var downloadedSongs: [Song] {
        songs.filter { $0.isDownloaded }
    }

    /// Canciones pendientes de descarga
    var pendingSongs: [Song] {
        songs.filter { !$0.isDownloaded }
    }

    /// Porcentaje de canciones descargadas (0.0 a 1.0)
    var downloadProgress: Double {
        guard !songs.isEmpty else { return 0.0 }
        return Double(downloadedSongs.count) / Double(songs.count)
    }

    /// Verifica si una canción está en la playlist
    func containsSong(id: UUID) -> Bool {
        songs.contains { $0.id == id }
    }
}
