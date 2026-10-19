//
//  ArtworkDecoder.swift
//  sinkmusic
//
//  Infrastructure Layer - Service
//

import Foundation
import UIKit
import ImageIO

/// Decodifica la carátula a la resolución en la que se va a ver.
///
/// `UIImage(data:)` decodifica a resolución nativa: una portada de 3000×3000 son 36 MB de
/// píxeles para pintarlos en una pantalla de 1290 px de ancho. Y lo hacía en el main actor,
/// justo durante la animación de apertura del reproductor.
///
/// `CGImageSourceCreateThumbnailAtIndex` decodifica **directo al tamaño objetivo**, con un
/// coste independiente de la resolución de origen. Es la misma técnica que usa
/// `ImageCompressionService` para los thumbnails, aquí para mostrar en vez de para guardar.
enum ArtworkDecoder {

    /// Lado máximo en píxeles para la carátula del reproductor grande. Por encima del ancho
    /// de pantalla de cualquier iPhone, así que no se nota en calidad.
    static let playerMaxPixelSize = 1024

    /// Decodifica fuera del main actor y entrega la imagen ya desconectada (`sending`), así
    /// que quien la recibe es su único dueño y no hace falta marcar nada como `Sendable`.
    nonisolated static func decode(
        _ data: Data,
        maxPixelSize: Int = playerMaxPixelSize
    ) async -> sending UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // Decodificar ya aquí: si no, el coste reaparece al pintar, en el main actor.
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
