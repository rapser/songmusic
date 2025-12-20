//
//  MetadataCacheViewModel.swift
//  sinkmusic
//
//  Created by Claude Code on 19/12/25.
//

import Foundation
import SwiftData
import UIKit

/// ViewModel responsable ÚNICAMENTE de cachear metadatos y artwork
/// Cumple con Single Responsibility Principle
@MainActor
class MetadataCacheViewModel: ObservableObject {
    @Published var cachedArtwork: UIImage?

    private let metadataService: MetadataServiceProtocol

    init(metadataService: MetadataServiceProtocol = MetadataService()) {
        self.metadataService = metadataService
    }

    /// Carga y cachea el artwork de una canción de forma síncrona
    /// - Parameter artworkData: Datos de la imagen
    func cacheArtwork(from artworkData: Data?) {
        guard let artworkData = artworkData else {
            cachedArtwork = nil
            return
        }

        // Decodificación síncrona para que esté lista inmediatamente
        cachedArtwork = UIImage(data: artworkData)
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
    }
}
