//
//  RefactoredSongListViewModel.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import Combine
import SwiftData

/// ViewModel refactorizado para la lista de canciones
/// Implementa MVVM correctamente con inyección de dependencias y UseCases
@MainActor
final class RefactoredSongListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (UseCases)
    private let downloadSongUseCase: DownloadSongUseCase
    private let deleteSongUseCase: DeleteSongUseCase
    private let downloadService: DownloadServiceProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization with Dependency Injection
    init(
        downloadService: DownloadServiceProtocol,
        metadataService: MetadataServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.downloadService = downloadService
        self.downloadSongUseCase = DownloadSongUseCase(
            googleDriveService: downloadService,
            metadataService: metadataService,
            songRepository: songRepository
        )
        self.deleteSongUseCase = DeleteSongUseCase(
            googleDriveService: downloadService,
            songRepository: songRepository
        )
        
        setupSubscriptions()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        downloadService.downloadProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (songID, progress) in
                self?.downloadProgress[songID] = progress
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func download(song: Song) {
        guard !song.isDownloaded else { return }
        
        downloadProgress[song.id] = -1 // Indeterminado
        
        Task {
            do {
                _ = try await downloadSongUseCase.execute(song: song)
                downloadProgress[song.id] = nil
            } catch {
                downloadProgress[song.id] = nil
                errorMessage = "Error al descargar \(song.title): \(error.localizedDescription)"
            }
        }
    }
    
    func deleteDownload(song: Song) {
        Task {
            do {
                try deleteSongUseCase.execute(song: song)
            } catch {
                errorMessage = "Error al eliminar \(song.title): \(error.localizedDescription)"
            }
        }
    }
}
