//
//  SyncLibraryUseCase.swift
//  sinkmusic
//
//  Created by Refactoring - Use Case Pattern
//

import Foundation

/// Caso de uso para sincronizar la biblioteca con Google Drive
/// Implementa Single Responsibility: solo se encarga de sincronizar la biblioteca
final class SyncLibraryUseCase {
    private let googleDriveService: GoogleDriveServiceProtocol
    private let songRepository: SongRepositoryProtocol
    
    init(
        googleDriveService: GoogleDriveServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.googleDriveService = googleDriveService
        self.songRepository = songRepository
    }
    
    /// Ejecuta la sincronización de la biblioteca
    /// - Returns: Tupla con número de canciones nuevas y actualizadas
    func execute() async throws -> (newSongs: Int, updatedSongs: Int) {
        print("🔄 Sincronizando biblioteca con Google Drive...")
        
        // Paso 1: Obtener canciones de Google Drive
        let driveFiles = try await googleDriveService.fetchSongsFromFolder()
        
        // Paso 2: Obtener canciones existentes
        let existingSongs = try songRepository.fetchAll()
        let existingSongsMap = Dictionary(uniqueKeysWithValues: existingSongs.map { ($0.fileID, $0) })
        
        var newSongsAdded = 0
        var songsUpdated = 0
        
        // Paso 3: Procesar cada archivo de Drive
        for driveFile in driveFiles {
            if let existingSong = existingSongsMap[driveFile.id] {
                // Solo actualizar si no tiene metadatos extraídos
                let hasMetadata = existingSong.duration != nil || existingSong.artworkData != nil
                
                if !hasMetadata && (existingSong.title != driveFile.title || existingSong.artist != driveFile.artist) {
                    existingSong.title = driveFile.title
                    existingSong.artist = driveFile.artist
                    try songRepository.update(existingSong)
                    songsUpdated += 1
                    print("📝 Actualizada: '\(driveFile.title)'")
                }
            } else {
                // Nueva canción
                let newSong = Song(
                    title: driveFile.title,
                    artist: driveFile.artist,
                    fileID: driveFile.id
                )
                try songRepository.save(newSong)
                newSongsAdded += 1
                print("➕ Nueva canción: '\(driveFile.title)'")
            }
        }
        
        print("✅ Sincronización completa: \(newSongsAdded) nuevas, \(songsUpdated) actualizadas")
        return (newSongsAdded, songsUpdated)
    }
}
