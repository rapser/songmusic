//
//  DeleteSongUseCase.swift
//  sinkmusic
//
//  Created by Refactoring - Use Case Pattern
//

import Foundation

/// Caso de uso para eliminar una canción descargada
/// Implementa Single Responsibility: solo se encarga de eliminar canciones
final class DeleteSongUseCase {
    private let googleDriveService: GoogleDriveServiceProtocol
    private let songRepository: SongRepositoryProtocol

    init(
        googleDriveService: GoogleDriveServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.googleDriveService = googleDriveService
        self.songRepository = songRepository
    }

    /// Ejecuta la eliminación completa de una canción
    /// - Parameter song: La canción a eliminar
    func execute(song: Song) throws {
        // Paso 1: Eliminar archivo local
        try googleDriveService.deleteDownload(for: song.id)
        
        // Paso 2: Resetear datos de la canción
        song.isDownloaded = false
        song.duration = nil
        song.artworkData = nil
        song.album = nil
        song.author = nil
        
        // Paso 3: Actualizar en el repositorio
        try songRepository.update(song)
    }
}
