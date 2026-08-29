//
//  ImageCompressionService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import UIKit
import ImageIO

/// Servicio para crear thumbnails comprimidos de artwork embebido.
///
/// Antes: `UIImage(data:)` decodificaba la portada a **resolución completa** (una portada
/// 3000×3000 se decodificaba entera), y eso pasaba **dos veces** (una por tamaño), seguido
/// de hasta 5 re-encodes JPEG por tamaño. El coste escalaba con la resolución de la portada
/// → "unas canciones rápido, otras lento".
///
/// Ahora: `CGImageSourceCreateThumbnailAtIndex` con `kCGImageSourceThumbnailMaxPixelSize`
/// decodifica **directo al tamaño objetivo** (coste independiente de la resolución de origen),
/// y se encodea una sola vez (con un único fallback si supera el presupuesto).
final class ImageCompressionService: ImageCompressionServiceProtocol, Sendable {

    /// Thumbnail pequeño para Live Activities (objetivo ≤ 1 KB, lado ≤ 32 px).
    static func createThumbnail(from imageData: Data) -> Data? {
        guard let source = makeSource(imageData) else { return nil }
        return encodedThumbnail(from: source, maxPixel: 32, budget: 1024, qualities: [0.10, 0.02])
    }

    /// Thumbnail mediano para filas de lista (objetivo ≤ 5 KB, lado ≤ 64 px).
    static func createMediumThumbnail(from imageData: Data) -> Data? {
        guard let source = makeSource(imageData) else { return nil }
        return encodedThumbnail(from: source, maxPixel: 64, budget: 5120, qualities: [0.40, 0.15])
    }

    /// Genera ambos tamaños reutilizando el mismo `CGImageSource` (una lectura del contenedor).
    /// Es lo que usa `MetadataService` en el pipeline de descarga.
    static func makeThumbnails(from imageData: Data) -> (small: Data?, medium: Data?) {
        guard let source = makeSource(imageData) else { return (nil, nil) }
        return (
            encodedThumbnail(from: source, maxPixel: 32, budget: 1024, qualities: [0.10, 0.02]),
            encodedThumbnail(from: source, maxPixel: 64, budget: 5120, qualities: [0.40, 0.15])
        )
    }

    // MARK: - Private

    private static func makeSource(_ data: Data) -> CGImageSource? {
        CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    }

    /// Decodifica al tamaño objetivo y encodea a JPEG. `qualities` = [intento, fallback].
    private static func encodedThumbnail(
        from source: CGImageSource,
        maxPixel: Int,
        budget: Int,
        qualities: [CGFloat]
    ) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)

        for (index, quality) in qualities.enumerated() {
            guard let data = image.jpegData(compressionQuality: quality) else { continue }
            // El último de la lista es el fallback: se devuelve aunque exceda el presupuesto.
            if data.count <= budget || index == qualities.count - 1 {
                return data
            }
        }
        return nil
    }
}
