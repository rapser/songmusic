//
//  ImageCompressionServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation

/// Protocolo para el servicio de compresión de imágenes
/// Permite mockear ImageCompressionService para testing
protocol ImageCompressionServiceProtocol: Sendable {

    // MARK: - Thumbnail Creation

    /// Crea un thumbnail pequeño optimizado para Live Activities (< 1KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createThumbnail(from imageData: Data) -> Data?

    /// Crea un thumbnail de tamaño medio para vistas de lista (< 5KB)
    /// - Parameter imageData: Datos de la imagen original
    /// - Returns: Datos de la imagen comprimida, o nil si falla
    static func createMediumThumbnail(from imageData: Data) -> Data?
}
