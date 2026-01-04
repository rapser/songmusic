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

    /// Limpia el cache de artwork
    func clearCache() {
        cachedArtwork = nil
        cachedThumbnail = nil
    }
}
