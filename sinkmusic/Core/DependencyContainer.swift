//
//  DependencyContainer.swift
//  sinkmusic
//
//  Created by Refactoring - Dependency Injection Container
//

import Foundation
import SwiftData

/// Contenedor de dependencias para gestionar la creación de objetos
/// Implementa el patrón Dependency Injection Container
/// Cumple con Single Responsibility: solo crea y gestiona dependencias
@MainActor
final class DependencyContainer {
    
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Services (Lazy initialization)
    private lazy var _audioPlayerService: AudioPlayerProtocol = {
        RefactoredAudioPlayerService()
    }()

    private lazy var _metadataService: MetadataServiceProtocol = {
        MetadataService()
    }()

    // GoogleDriveService ahora incluye toda la funcionalidad de descarga
    private lazy var _googleDriveService: GoogleDriveServiceProtocol = {
        GoogleDriveService()
    }()
    
    // MARK: - Repositories
    private var songRepositoryCache: [ObjectIdentifier: SongRepositoryProtocol] = [:]
    private var playlistRepositoryCache: [ObjectIdentifier: PlaylistRepositoryProtocol] = [:]
    
    private init() {}
    
    // MARK: - Services Accessors
    func audioPlayerService() -> AudioPlayerProtocol {
        _audioPlayerService
    }

    func metadataService() -> MetadataServiceProtocol {
        _metadataService
    }

    func googleDriveService() -> GoogleDriveServiceProtocol {
        _googleDriveService
    }

    // Alias para compatibilidad: downloadService ahora apunta a googleDriveService
    func downloadService() -> GoogleDriveServiceProtocol {
        _googleDriveService
    }
    
    // MARK: - Repositories (Context-dependent)
    func songRepository(modelContext: ModelContext) -> SongRepositoryProtocol {
        let key = ObjectIdentifier(modelContext)
        if let cached = songRepositoryCache[key] {
            return cached
        }
        
        let repository = SongRepository(modelContext: modelContext)
        songRepositoryCache[key] = repository
        return repository
    }
    
    func playlistRepository(modelContext: ModelContext) -> PlaylistRepositoryProtocol {
        let key = ObjectIdentifier(modelContext)
        if let cached = playlistRepositoryCache[key] {
            return cached
        }
        
        let repository = PlaylistRepository(modelContext: modelContext)
        playlistRepositoryCache[key] = repository
        return repository
    }
    
    // MARK: - ViewModels Factory Methods
    func makePlayerViewModel(modelContext: ModelContext) -> RefactoredPlayerViewModel {
        RefactoredPlayerViewModel(
            audioPlayer: audioPlayerService(),
            downloadService: downloadService(),
            metadataService: metadataService(),
            songRepository: songRepository(modelContext: modelContext)
        )
    }
    
    func makeMainViewModel(modelContext: ModelContext) -> RefactoredMainViewModel {
        let playerVM = makePlayerViewModel(modelContext: modelContext)
        
        return RefactoredMainViewModel(
            playerViewModel: playerVM,
            googleDriveService: googleDriveService(),
            songRepository: songRepository(modelContext: modelContext)
        )
    }
    
    func makeSongListViewModel(modelContext: ModelContext) -> RefactoredSongListViewModel {
        RefactoredSongListViewModel(
            downloadService: downloadService(),
            metadataService: metadataService(),
            songRepository: songRepository(modelContext: modelContext)
        )
    }
    
    func makePlaylistViewModel(modelContext: ModelContext) -> RefactoredPlaylistViewModel {
        RefactoredPlaylistViewModel(
            playlistRepository: playlistRepository(modelContext: modelContext)
        )
    }
    
    // MARK: - Testing Support
    /// Limpia el cache de repositorios (útil para testing)
    func clearRepositoryCache() {
        songRepositoryCache.removeAll()
        playlistRepositoryCache.removeAll()
    }
}
