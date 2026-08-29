//
//  SongUI.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Modelo de UI para presentar canciones en las vistas
/// Contiene solo datos necesarios para la UI, ya formateados
struct SongUI: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: String // Ya formateado (ej: "03:45")
    let durationSeconds: TimeInterval // Duracion en segundos (para PlayerViewModel)
    let artworkThumbnail: Data? // Thumbnail mediano para listas (64x64)
    let artworkSmallThumbnail: Data? // Thumbnail pequeño para Live Activity (32x32)
    let isDownloaded: Bool
    let dominantColor: Color?
    /// Color de fondo del reproductor, ya resuelto en el mapper (no se recalcula en cada render).
    let backgroundColor: Color
    let artistAlbumInfo: String // Ya formateado (ej: "Artist • Album")

    // MARK: - Computed Properties para UI

    /// Indica si debe mostrar badge de descargado
    var showDownloadedBadge: Bool {
        isDownloaded
    }

    /// Indica si tiene artwork para mostrar
    var hasArtwork: Bool {
        artworkThumbnail != nil
    }

    // MARK: - Hashable / Equatable

    /// Conformidad manual: **excluye los blobs de imagen** de `==` y `hash`.
    ///
    /// `SongUI` se usa como elemento de `ForEach`; con la síntesis automática, cada diff de
    /// lista hacía `memcmp` de `artworkThumbnail` + `artworkSmallThumbnail` (varios KB) por
    /// fila (hallazgo E de la auditoría). Aquí se compara identidad + campos escalares de
    /// presentación; para detectar "apareció/cambió la carátula" sin comparar los bytes se
    /// usa `count` como proxy O(1) (una colisión de tamaño se auto-corrige en el siguiente diff).
    static func == (lhs: SongUI, rhs: SongUI) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.duration == rhs.duration &&
        lhs.durationSeconds == rhs.durationSeconds &&
        lhs.isDownloaded == rhs.isDownloaded &&
        lhs.dominantColor == rhs.dominantColor &&
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.artistAlbumInfo == rhs.artistAlbumInfo &&
        lhs.artworkThumbnail?.count == rhs.artworkThumbnail?.count &&
        lhs.artworkSmallThumbnail?.count == rhs.artworkSmallThumbnail?.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(isDownloaded)
        hasher.combine(artworkThumbnail?.count)
    }

    /// Copia la canción con un nuevo color dominante (para actualizar en lista tras persistir).
    func with(dominantColor newColor: Color?) -> SongUI {
        SongUI(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            durationSeconds: durationSeconds,
            artworkThumbnail: artworkThumbnail,
            artworkSmallThumbnail: artworkSmallThumbnail,
            isDownloaded: isDownloaded,
            dominantColor: newColor,
            backgroundColor: newColor ?? backgroundColor,
            artistAlbumInfo: artistAlbumInfo
        )
    }
}
