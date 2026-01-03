//
//  DIContainer.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftData

/// Contenedor de Dependency Injection - Centro neurálgico de Clean Architecture
@MainActor
final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    // MARK: - SwiftData Context
    private var modelContext: ModelContext?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Infrastructure Services (Singleton)

    private(set) lazy var audioPlayerService: AudioPlayerService = AudioPlayerService()

    private(set) lazy var liveActivityService: LiveActivityService = LiveActivityService()

    private(set) lazy var keychainService: KeychainService = KeychainService.shared

    private(set) lazy var authManager: AuthenticationManager = AuthenticationManager.shared

    // MARK: - Repositories (Lazy initialization)

    private(set) lazy var songRepository: SongRepositoryProtocol = makeSongRepository()

    private(set) lazy var playlistRepository: PlaylistRepositoryProtocol = makePlaylistRepository()

    private(set) lazy var audioPlayerRepository: AudioPlayerRepositoryProtocol = makeAudioPlayerRepository()

    private(set) lazy var googleDriveRepository: GoogleDriveRepositoryProtocol = makeGoogleDriveRepository()

    private(set) lazy var credentialsRepository: CredentialsRepositoryProtocol = makeCredentialsRepository()

    private(set) lazy var metadataRepository: MetadataRepositoryProtocol = makeMetadataRepository()

    // MARK: - Use Cases (Lazy initialization)

    private(set) lazy var playerUseCases: PlayerUseCases = makePlayerUseCases()

    private(set) lazy var equalizerUseCases: EqualizerUseCases = makeEqualizerUseCases()

    private(set) lazy var libraryUseCases: LibraryUseCases = makeLibraryUseCases()

    private(set) lazy var playlistUseCases: PlaylistUseCases = makePlaylistUseCases()

    private(set) lazy var searchUseCases: SearchUseCases = makeSearchUseCases()

    private(set) lazy var downloadUseCases: DownloadUseCases = makeDownloadUseCases()

    private(set) lazy var settingsUseCases: SettingsUseCases = makeSettingsUseCases()

    // MARK: - Repository Factories

    private func makeSongRepository() -> SongRepositoryProtocol {
        guard let context = modelContext else {
            fatalError("❌ DIContainer: ModelContext no configurado. Llama a configure(with:) primero.")
        }
        let localDataSource = SongLocalDataSource(modelContext: context)
        return SongRepositoryImpl(localDataSource: localDataSource)
    }

    private func makePlaylistRepository() -> PlaylistRepositoryProtocol {
        guard let context = modelContext else {
            fatalError("❌ DIContainer: ModelContext no configurado. Llama a configure(with:) primero.")
        }
        let localDataSource = PlaylistLocalDataSource(modelContext: context)
        return PlaylistRepositoryImpl(localDataSource: localDataSource, songRepository: songRepository)
    }

    private func makeAudioPlayerRepository() -> AudioPlayerRepositoryProtocol {
        AudioPlayerRepositoryImpl(
            audioPlayerService: audioPlayerService,
            liveActivityService: liveActivityService
        )
    }

    private func makeGoogleDriveRepository() -> GoogleDriveRepositoryProtocol {
        GoogleDriveRepositoryImpl(
            remoteDataSource: GoogleDriveRemoteDataSource(),
            credentialsRepository: credentialsRepository
        )
    }

    private func makeCredentialsRepository() -> CredentialsRepositoryProtocol {
        CredentialsRepositoryImpl(keychainService: keychainService)
    }

    private func makeMetadataRepository() -> MetadataRepositoryProtocol {
        MetadataRepositoryImpl(
            metadataService: MetadataService(),
            imageCompressionService: ImageCompressionService()
        )
    }

    // MARK: - Use Case Factories

    private func makePlayerUseCases() -> PlayerUseCases {
        PlayerUseCases(
            audioPlayerRepository: audioPlayerRepository,
            songRepository: songRepository
        )
    }

    private func makeEqualizerUseCases() -> EqualizerUseCases {
        EqualizerUseCases(audioPlayerRepository: audioPlayerRepository)
    }

    private func makeLibraryUseCases() -> LibraryUseCases {
        LibraryUseCases(
            songRepository: songRepository,
            googleDriveRepository: googleDriveRepository,
            credentialsRepository: credentialsRepository
        )
    }

    private func makePlaylistUseCases() -> PlaylistUseCases {
        PlaylistUseCases(
            playlistRepository: playlistRepository,
            songRepository: songRepository
        )
    }

    private func makeSearchUseCases() -> SearchUseCases {
        SearchUseCases(songRepository: songRepository)
    }

    private func makeDownloadUseCases() -> DownloadUseCases {
        DownloadUseCases(
            songRepository: songRepository,
            googleDriveRepository: googleDriveRepository,
            metadataRepository: metadataRepository
        )
    }

    private func makeSettingsUseCases() -> SettingsUseCases {
        SettingsUseCases(
            credentialsRepository: credentialsRepository,
            songRepository: songRepository,
            googleDriveRepository: googleDriveRepository
        )
    }

    // MARK: - ViewModel Factories

    /// Factory para PlayerViewModel - Crea nueva instancia cada vez
    func makePlayerViewModel() -> PlayerViewModel {
        PlayerViewModel(
            playerUseCases: playerUseCases,
            songRepository: songRepository
        )
    }

    /// Factory para LibraryViewModel - Crea nueva instancia cada vez
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(libraryUseCases: libraryUseCases)
    }

    /// Factory para PlaylistViewModel - Crea nueva instancia cada vez
    func makePlaylistViewModel() -> PlaylistViewModel {
        PlaylistViewModel(playlistUseCases: playlistUseCases)
    }

    /// Factory para SearchViewModel - Crea nueva instancia cada vez
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchUseCases: searchUseCases)
    }

    /// Factory para SettingsViewModel - Crea nueva instancia cada vez
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsUseCases: settingsUseCases,
            downloadUseCases: downloadUseCases
        )
    }

    /// Factory para EqualizerViewModel - Crea nueva instancia cada vez
    func makeEqualizerViewModel() -> EqualizerViewModel {
        EqualizerViewModel(equalizerUseCases: equalizerUseCases)
    }

    /// Factory para HomeViewModel - Crea nueva instancia cada vez
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            playlistUseCases: playlistUseCases,
            songRepository: songRepository
        )
    }
}
