//
//  ImageCompressionService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import UIKit

/// Servicio para comprimir y crear thumbnails de imágenes
final class ImageCompressionService: ImageCompressionServiceProtocol, Sendable {

    /// Crea un thumbnail pequeño optimizado para Live Activities (< 1KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // Tamaño objetivo: 32x32 píxeles (más pequeño para cumplir límite de 1KB)
        let targetSize = CGSize(width: 32, height: 32)

        // Redimensionar la imagen
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Comprimir con calidad muy baja para cumplir límite de 1KB
        // Intentar con diferentes niveles de compresión
        let qualityLevels: [CGFloat] = [0.15, 0.1, 0.05, 0.02]

        for quality in qualityLevels {
            if let compressedData = resizedImage.jpegData(compressionQuality: quality),
               compressedData.count <= 1024 {
                return compressedData
            }
        }

        // Si aún es muy grande, usar la compresión mínima
        return resizedImage.jpegData(compressionQuality: 0.01)
    }

    /// Crea un thumbnail de tamaño medio para vistas de lista (< 5KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createMediumThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // Tamaño objetivo: 64x64 píxeles (suficiente para vistas de lista que usan 56x56)
        let targetSize = CGSize(width: 64, height: 64)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Intentar con diferentes niveles de calidad para cumplir límite de 5KB
        let qualityLevels: [CGFloat] = [0.5, 0.4, 0.3, 0.2]

        for quality in qualityLevels {
            if let compressedData = resizedImage.jpegData(compressionQuality: quality),
               compressedData.count <= 5120 {
                return compressedData
            }
        }

        // Si aún es muy grande, usar compresión baja
        return resizedImage.jpegData(compressionQuality: 0.15)
    }
}
