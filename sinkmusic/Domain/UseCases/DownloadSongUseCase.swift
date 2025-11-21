//
//  DownloadSongUseCase.swift
//  sinkmusic
//
//  Created by Refactoring - Use Case Pattern
//

import Foundation

/// Caso de uso para descargar una canción y extraer sus metadatos
/// Implementa Single Responsibility: solo se encarga de orquestar la descarga completa
final class DownloadSongUseCase {
    private let downloadService: DownloadServiceProtocol
    private let metadataService: MetadataServiceProtocol
    private let songRepository: SongRepositoryProtocol
    
    init(
        downloadService: DownloadServiceProtocol,
        metadataService: MetadataServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.downloadService = downloadService
        self.metadataService = metadataService
        self.songRepository = songRepository
    }
    
    /// Ejecuta la descarga completa de una canción con extracción de metadatos
    /// - Parameter song: La canción a descargar
    /// - Returns: URL local del archivo descargado
    func execute(song: Song) async throws -> URL {
        // Paso 1: Descargar el archivo
        print("📥 Iniciando descarga: \(song.title)")
        let localURL = try await downloadService.download(song: song)
        
        // Paso 2: Marcar como descargada
        song.isDownloaded = true
        
        // Paso 3: Extraer metadatos
        print("📥 Extrayendo metadatos desde: \(localURL.path)")
        if let metadata = await metadataService.extractMetadata(from: localURL) {
            song.title = metadata.title
            song.artist = metadata.artist
            song.album = metadata.album
            song.author = metadata.author
            song.duration = metadata.duration
            song.artworkData = metadata.artwork
            print("✅ Metadatos actualizados: \(song.title) - \(song.artist)")
        } else {
            print("⚠️ No se pudieron extraer metadatos")
        }
        
        // Paso 4: Guardar en el repositorio
        try songRepository.update(song)
        print("💾 Canción guardada en repositorio")
        
        return localURL
    }
}
