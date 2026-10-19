//
//  MetadataCacheViewModel.swift
//  sinkmusic
//
//  Created by Miguel Tomairo on 19/12/25.
//  Refactored to Clean Architecture - Solo cacheo de artwork
//

import Foundation
import UIKit

/// ViewModel responsable ÚNICAMENTE de cachear artwork en memoria
/// Cumple con Single Responsibility Principle
/// NO tiene lógica de negocio, solo cache visual para UI
@MainActor
@Observable
final class MetadataCacheViewModel {
    var cachedArtwork: UIImage?        // Imagen completa para PlayerView
    var cachedThumbnail: UIImage?      // Thumbnail para MiniPlayer (42x42)

    init() {}

    // MARK: - Cache Operations

    /// Cachea el thumbnail del mini player. Son unos pocos KB: decodificar aquí es barato.
    ///
    /// Antes esto y la carátula grande eran una sola función, y el coordinador la llamaba
    /// **dos veces** por cambio de canción —una para mostrar el thumbnail ya, otra al llegar
    /// la imagen completa—, así que el thumbnail se decodificaba dos veces por canción.
    /// Separadas, cada decodificación ocurre una vez.
    func cacheThumbnail(from thumbnailData: Data?) {
        cachedThumbnail = thumbnailData.flatMap { UIImage(data: $0) }
    }

    /// Cachea la carátula del reproductor grande, decodificada fuera del main actor y al
    /// tamaño en el que se va a ver (ver `ArtworkDecoder`).
    func cacheFullArtwork(from artworkData: Data?) async {
        guard let artworkData else {
            cachedArtwork = nil
            return
        }
        cachedArtwork = await ArtworkDecoder.decode(artworkData)
    }

    /// Limpia el cache de artwork
    func clearCache() {
        cachedArtwork = nil
        cachedThumbnail = nil
    }
}
