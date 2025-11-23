//
//  MetadataServiceProtocol.swift
//  sinkmusic
//
//  Created by Refactoring - SOLID Principles
//

import Foundation

/// Protocolo que define las capacidades del servicio de metadatos
/// Cumple con Dependency Inversion Principle (SOLID)
protocol MetadataServiceProtocol {
    /// Extrae los metadatos de un archivo de audio
    /// - Parameter url: URL del archivo de audio
    /// - Returns: Metadatos extraídos o nil si falla
    func extractMetadata(from url: URL) async -> SongMetadata?
}
