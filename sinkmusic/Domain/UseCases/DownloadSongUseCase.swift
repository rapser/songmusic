//
//  DownloadSongUseCase.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation

/// Caso de uso para descargar una canción y extraer sus metadatos
/// Implementa Single Responsibility: solo se encarga de orquestar la descarga completa
final class DownloadSongUseCase {
    private let googleDriveService: GoogleDriveServiceProtocol
    private let metadataService: MetadataServiceProtocol
    private let songRepository: SongRepositoryProtocol

    init(
        googleDriveService: GoogleDriveServiceProtocol,
        metadataService: MetadataServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.googleDriveService = googleDriveService
        self.metadataService = metadataService
        self.songRepository = songRepository
    }
    
    /// Ejecuta la descarga completa de una canción con extracción de metadatos
    /// - Parameter song: La canción a descargar
    /// - Returns: URL local del archivo descargado
    func execute(song: Song) async throws -> URL {
        // Paso 1: Descargar el archivo
        let localURL = try await googleDriveService.download(song: song)
        
        // Paso 2: Marcar como descargada
        song.isDownloaded = true
        
        // Paso 3: Extraer metadatos
        if let metadata = await metadataService.extractMetadata(from: localURL) {
            song.title = metadata.title
            song.artist = metadata.artist
            song.album = metadata.album
            song.author = metadata.author
            song.duration = metadata.duration
            song.artworkData = metadata.artwork
            song.artworkThumbnail = metadata.artworkThumbnail
            song.artworkMediumThumbnail = metadata.artworkMediumThumbnail
        }
        
        // Paso 4: Guardar en el repositorio
        try songRepository.update(song)
        
        return localURL
    }
}
