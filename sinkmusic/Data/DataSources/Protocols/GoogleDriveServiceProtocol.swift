//
//  GoogleDriveServiceProtocol.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

/// Protocolo consolidado que define las capacidades del servicio de Google Drive
/// Incluye funcionalidad de descarga y manejo de archivos locales
/// Cumple con Dependency Inversion Principle (SOLID)
protocol GoogleDriveServiceProtocol {
    // MARK: - Fetch Songs

    /// Obtiene la lista de canciones de una carpeta de Google Drive
    /// - Returns: Array de archivos encontrados
    func fetchSongsFromFolder() async throws -> [GoogleDriveFile]

    /// Construye la URL de descarga directa para un archivo
    /// - Parameter fileId: Identificador del archivo en Google Drive
    /// - Returns: URL de descarga
    func getDownloadURL(for fileId: String) -> String

    // MARK: - Download

    /// Descarga una canción de Google Drive con callback de progreso
    /// - Parameters:
    ///   - fileID: Identificador del archivo en Google Drive
    ///   - songID: Identificador de la canción
    ///   - progressCallback: Closure que recibe el progreso (0.0 a 1.0)
    /// - Returns: URL local donde se guardó el archivo
    func download(fileID: String, songID: UUID, progressCallback: @escaping (Double) -> Void) async throws -> URL

    // MARK: - Local File Management

    /// Obtiene la URL local de una canción descargada
    /// - Parameter songID: Identificador de la canción
    /// - Returns: URL local si existe, nil en caso contrario
    func localURL(for songID: UUID) -> URL?

    /// Obtiene la duración de un archivo de audio
    /// - Parameter url: URL del archivo
    /// - Returns: Duración en segundos, nil si falla
    func getDuration(for url: URL) -> TimeInterval?

    /// Elimina el archivo descargado de una canción
    /// - Parameter songID: Identificador de la canción
    func deleteDownload(for songID: UUID) throws
}
