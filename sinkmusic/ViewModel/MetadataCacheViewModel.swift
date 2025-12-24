//
//  MetadataCacheViewModel.swift
//  sinkmusic
//
//  Created by Miguel Tomairo on 19/12/25.
//

import Foundation
import SwiftData
import UIKit

/// ViewModel responsable ÚNICAMENTE de cachear metadatos y artwork
/// Cumple con Single Responsibility Principle
@MainActor
class MetadataCacheViewModel: ObservableObject {
    @Published var cachedArtwork: UIImage?        // Imagen completa para PlayerView
    @Published var cachedThumbnail: UIImage?      // Thumbnail para MiniPlayer (42x42)

    private let metadataService: MetadataServiceProtocol

    init(metadataService: MetadataServiceProtocol = MetadataService()) {
        self.metadataService = metadataService
    }

    /// Carga y cachea el artwork de una canción de forma optimizada
    /// - Parameters:
    ///   - artworkData: Datos de la imagen completa
    ///   - thumbnailData: Datos del thumbnail (opcional, más eficiente)
    /// - Note: Usa thumbnail para mini player (42x42) y artwork completo para player grande
    func cacheArtwork(from artworkData: Data?, thumbnail thumbnailData: Data?) {
        // OPTIMIZACIÓN: Cachear thumbnail pequeño para mini player (42x42)
        if let thumbnailData = thumbnailData {
            cachedThumbnail = UIImage(data: thumbnailData)
        } else if let artworkData = artworkData {
            // Fallback: si no hay thumbnail, usar artwork completo
            cachedThumbnail = UIImage(data: artworkData)
        } else {
            cachedThumbnail = nil
        }

        // Cachear imagen completa para PlayerView grande
        if let artworkData = artworkData {
            cachedArtwork = UIImage(data: artworkData)
        } else {
            cachedArtwork = nil
        }
    }

    /// Extrae metadatos de un archivo de audio en background
    /// - Parameters:
    ///   - url: URL del archivo de audio
    ///   - song: Canción a actualizar con los metadatos
    func extractAndCacheMetadata(from url: URL, for song: Song) async {
        guard let metadata = await metadataService.extractMetadata(from: url) else {
            return
        }

        // Actualizar la canción con los metadatos extraídos
        song.title = metadata.title
        song.artist = metadata.artist
        song.album = metadata.album
        song.author = metadata.author
        song.duration = metadata.duration
        song.artworkData = metadata.artwork
        song.artworkThumbnail = metadata.artworkThumbnail
        song.artworkMediumThumbnail = metadata.artworkMediumThumbnail

        // Actualizar el cache de artwork si hay datos
        if let artworkData = metadata.artwork {
            await MainActor.run {
                self.cachedArtwork = UIImage(data: artworkData)
            }
        }
    }

    /// Limpia el cache de artwork
    func clearCache() {
        cachedArtwork = nil
        cachedThumbnail = nil
    }
}
