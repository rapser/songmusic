//
//  DIContainer.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//  Refactored: Sin singletons, DI puro
//

import Foundation
import SwiftData

/// Contenedor de Dependency Injection - Centro neurálgico de Clean Architecture
/// SOLID: Sin singletons internos, todas las dependencias se crean aquí
@MainActor
final class DIContainer {

    // MARK: - Singleton (único permitido - punto de entrada)

    static let shared = DIContainer()

    private init() {
        // Crear EventBus primero ya que es usado por otros componentes
        _eventBus = EventBus()
    }

    // MARK: - SwiftData Context

    private var modelContext: ModelContext?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        // Iniciar verificación de autenticación después de configurar
        authDIContainer.authRepository.checkAuthenticationState()
    }

    // MARK: - Core Services (Creados una sola vez)

    /// EventBus - Instancia única creada en init
    private let _eventBus: EventBus

    /// EventBus como protocolo para DI
    var eventBus: EventBusProtocol { _eventBus }

    /// KeychainService - Creado una sola vez (no singleton)
    private(set) lazy var keychainService: KeychainServiceProtocol = KeychainService()

    /// AudioPlayerService - Creado una sola vez
    private(set) lazy var audioPlayerService: AudioPlayerServiceProtocol = AudioPlayerService(eventBus: eventBus)

    /// LiveActivityService - Creado una sola vez
    private(set) lazy var liveActivityService: LiveActivityServiceProtocol = LiveActivityService()

    /// CarPlayService - Creado una sola vez
    private(set) lazy var carPlayService: CarPlayServiceProtocol = CarPlayService()

    // MARK: - Feature Modules

    /// Auth Module DI Container
    private(set) lazy var authDIContainer: AuthDIContainer = AuthDIContainer(eventBus: eventBus)

    // MARK: - Repositories (Lazy initialization)

    private(set) lazy var songRepository: SongRepositoryProtocol = makeSongRepository()

    private(set) lazy var playlistRepository: PlaylistRepositoryProtocol = makePlaylistRepository()

    private(set) lazy var audioPlayerRepository: AudioPlayerRepositoryProtocol = makeAudioPlayerRepository()

    private(set) lazy var cloudStorageRepository: CloudStorageRepositoryProtocol = makeCloudStorageRepository()

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
        let localDataSource = SongLocalDataSource(modelContext: context, eventBus: eventBus)
        return SongRepositoryImpl(localDataSource: localDataSource)
    }

    private func makePlaylistRepository() -> PlaylistRepositoryProtocol {
        guard let context = modelContext else {
            fatalError("❌ DIContainer: ModelContext no configurado. Llama a configure(with:) primero.")
        }
        let localDataSource = PlaylistLocalDataSource(modelContext: context, eventBus: eventBus)
        return PlaylistRepositoryImpl(localDataSource: localDataSource, songRepository: songRepository)
    }

    private func makeAudioPlayerRepository() -> AudioPlayerRepositoryProtocol {
        AudioPlayerRepositoryImpl(audioPlayerService: audioPlayerService)
    }

    private func makeCloudStorageRepository() -> CloudStorageRepositoryProtocol {
        guard let context = modelContext else {
            fatalError("❌ DIContainer: ModelContext no configurado. Llama a configure(with:) primero.")
        }
        let songLocalDataSource = SongLocalDataSource(modelContext: context, eventBus: eventBus)
        let googleDriveDataSource = GoogleDriveDataSource(keychainService: keychainService, eventBus: eventBus)
        return CloudStorageRepositoryImpl(
            googleDriveDataSource: googleDriveDataSource,
            songLocalDataSource: songLocalDataSource
        )
    }

    private func makeCredentialsRepository() -> CredentialsRepositoryProtocol {
        CredentialsRepositoryImpl(keychainService: keychainService)
    }

    private func makeMetadataRepository() -> MetadataRepositoryProtocol {
        let metadataService = MetadataService()
        return MetadataRepositoryImpl(metadataService: metadataService)
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
            cloudStorageRepository: cloudStorageRepository,
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
            cloudStorageRepository: cloudStorageRepository,
            metadataRepository: metadataRepository
        )
    }

    private func makeSettingsUseCases() -> SettingsUseCases {
        SettingsUseCases(
            credentialsRepository: credentialsRepository,
            songRepository: songRepository,
            cloudStorageRepository: cloudStorageRepository
        )
    }

    // MARK: - ViewModel Factories

    /// Factory para PlayerViewModel
    func makePlayerViewModel() -> PlayerViewModel {
        PlayerViewModel(playerUseCases: playerUseCases, eventBus: eventBus)
    }

    /// Factory para LibraryViewModel
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(libraryUseCases: libraryUseCases, eventBus: eventBus)
    }

    /// Factory para PlaylistViewModel
    func makePlaylistViewModel() -> PlaylistViewModel {
        PlaylistViewModel(playlistUseCases: playlistUseCases, eventBus: eventBus)
    }

    /// Factory para SearchViewModel
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchUseCases: searchUseCases)
    }

    /// Factory para SettingsViewModel
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsUseCases: settingsUseCases,
            downloadUseCases: downloadUseCases
        )
    }

    /// Factory para EqualizerViewModel
    func makeEqualizerViewModel() -> EqualizerViewModel {
        EqualizerViewModel(equalizerUseCases: equalizerUseCases)
    }

    /// Factory para HomeViewModel
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            playlistUseCases: playlistUseCases,
            libraryUseCases: libraryUseCases,
            eventBus: eventBus
        )
    }

    /// Factory para DownloadViewModel
    func makeDownloadViewModel() -> DownloadViewModel {
        DownloadViewModel(downloadUseCases: downloadUseCases, eventBus: eventBus)
    }

    /// Factory para AuthViewModel (nuevo módulo Auth)
    func makeAuthViewModel() -> AuthViewModel {
        authDIContainer.makeAuthViewModel()
    }
}
