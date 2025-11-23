//
//  RefactoredMainViewModel.swift
//  sinkmusic
//
//  Created by Refactoring - MVVM + SOLID
//

import Foundation
import Combine
import SwiftData

/// ViewModel principal refactorizado
/// Implementa MVVM correctamente con inyección de dependencias y UseCases
@MainActor
final class RefactoredMainViewModel: ObservableObject, ScrollStateResettable {
    
    // MARK: - Published Properties
    @Published var isScrolling: Bool = false
    @Published var isLoadingSongs: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Child ViewModels
    var playerViewModel: RefactoredPlayerViewModel
    
    // MARK: - Dependencies (UseCases)
    private let syncLibraryUseCase: SyncLibraryUseCase
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization with Dependency Injection
    init(
        playerViewModel: RefactoredPlayerViewModel,
        googleDriveService: GoogleDriveServiceProtocol,
        songRepository: SongRepositoryProtocol
    ) {
        self.playerViewModel = playerViewModel
        self.syncLibraryUseCase = SyncLibraryUseCase(
            googleDriveService: googleDriveService,
            songRepository: songRepository
        )
        
        self.playerViewModel.scrollResetter = self
    }
    
    // MARK: - ScrollStateResettable Protocol
    func resetScrollState() {
        isScrolling = false
    }
    
    // MARK: - Public Methods
    func syncLibrary() {
        isLoadingSongs = true
        errorMessage = nil
        
        Task {
            do {
                let _ = try await syncLibraryUseCase.execute()
                
                isLoadingSongs = false
            } catch {
                isLoadingSongs = false
                errorMessage = "Error al sincronizar: \(error.localizedDescription)"
            }
        }
    }
}
