//
//  ImageCompressionService.swift
//  sinkmusic
//
//  Created by Claude Code
//

import UIKit

/// Servicio para comprimir y crear thumbnails de imágenes
class ImageCompressionService {

    /// Crea un thumbnail pequeño optimizado para Live Activities (< 1KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // Tamaño objetivo: 40x40 píxeles (suficiente para el Dynamic Island)
        let targetSize = CGSize(width: 40, height: 40)

        // Redimensionar la imagen
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Comprimir con calidad baja pero suficiente para un thumbnail
        // Objetivo: menos de 1KB
        guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
            return nil
        }

        // Verificar que no exceda 1KB
        if compressedData.count > 1024 {
            // Si aún es muy grande, comprimir más
            return resizedImage.jpegData(compressionQuality: 0.1)
        }

        return compressedData
    }

    /// Crea un thumbnail de tamaño medio para vistas de lista (< 10KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createMediumThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // Tamaño objetivo: 100x100 píxeles
        let targetSize = CGSize(width: 100, height: 100)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Comprimir con calidad media
        return resizedImage.jpegData(compressionQuality: 0.5)
    }
}
