//
//  GoogleDriveServiceProtocol.swift
//  sinkmusic
//
//  Created by Refactoring - SOLID Principles
//

import Foundation

/// Protocolo que define las capacidades del servicio de Google Drive
/// Cumple con Dependency Inversion Principle (SOLID)
protocol GoogleDriveServiceProtocol {
    /// Obtiene la lista de canciones de una carpeta de Google Drive
    /// - Returns: Array de archivos encontrados
    func fetchSongsFromFolder() async throws -> [GoogleDriveFile]
    
    /// Construye la URL de descarga directa para un archivo
    /// - Parameter fileId: Identificador del archivo en Google Drive
    /// - Returns: URL de descarga
    func getDownloadURL(for fileId: String) -> String
}
