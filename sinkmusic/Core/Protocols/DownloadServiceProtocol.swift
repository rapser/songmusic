//
//  DownloadServiceProtocol.swift
//  sinkmusic
//
//  Created by Refactoring - SOLID Principles
//

import Foundation
import Combine

/// Protocolo que define las capacidades del servicio de descargas
/// Cumple con Dependency Inversion Principle (SOLID)
protocol DownloadServiceProtocol {
    /// Publisher que emite el progreso de descargas
    var downloadProgressPublisher: PassthroughSubject<(songID: UUID, progress: Double), Never> { get }
    
    /// Descarga una canción
    /// - Parameter song: La canción a descargar
    /// - Returns: URL local donde se guardó el archivo
    func download(song: Song) async throws -> URL
    
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
