//
//  PlaySongUseCase.swift
//  sinkmusic
//
//  Created by Refactoring - Use Case Pattern
//

import Foundation

/// Caso de uso para reproducir una canción
/// Implementa Single Responsibility: solo se encarga de iniciar la reproducción
final class PlaySongUseCase {
    private let audioPlayer: AudioPlayerProtocol
    private let downloadService: DownloadServiceProtocol
    private let metadataService: MetadataServiceProtocol
    private let songRepository: SongRepositoryProtocol
    
    init(
        audioPlayer: AudioPlayerProtocol,
        downloadService: DownloadServiceProtocol,
        metadataService: MetadataServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.audioPlayer = audioPlayer
        self.downloadService = downloadService
        self.metadataService = metadataService
        self.songRepository = songRepository
    }
    
    /// Ejecuta la reproducción de una canción
    /// - Parameter song: La canción a reproducir
    /// - Throws: AppError si la canción no está descargada o no se encuentra el archivo
    func execute(song: Song) async throws {
        guard song.isDownloaded else {
            throw AppError.audio(.fileNotFound)
        }
        
        guard let url = downloadService.localURL(for: song.id) else {
            throw AppError.storage(.fileNotFound)
        }
        
        // Extraer metadatos si no existen (para canciones descargadas antes del cambio)
        if song.duration == nil || song.artworkData == nil {
            if let metadata = await metadataService.extractMetadata(from: url) {
                song.title = metadata.title
                song.artist = metadata.artist
                song.album = metadata.album
                song.author = metadata.author
                song.duration = metadata.duration
                song.artworkData = metadata.artwork
                
                try? songRepository.update(song)
            }
        }
        
        // Iniciar reproducción
        audioPlayer.play(songID: song.id, url: url)
    }
}
