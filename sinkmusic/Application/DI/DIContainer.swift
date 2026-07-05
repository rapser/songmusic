//
//  DIContainer.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//  Refactored: Facade + Strategy para Auth
//

import Foundation
import SwiftData

/// Contenedor de Dependency Injection — centro neurálgico de Clean Architecture.
///
/// **Ciclo de vida:**
/// `sinkmusicApp.init()` crea la instancia y la registra en `DIContainer.shared` mediante
/// `createShared()`. `AppDelegate` la consume para el completion handler de sesiones en
/// segundo plano. Los **tests nunca usan este contenedor**: instancian UseCases directamente
/// pasando mocks al constructor, sin pasar por aquí.
@MainActor
final class DIContainer {

    // MARK: - Shared instance

    /// Referencia registrada por `sinkmusicApp` al arrancar la app.
    /// Sólo `createShared()` puede escribir aquí; todos los demás solo leen.
    private(set) static var shared: DIContainer!

    /// Crea la instancia compartida y la registra en `shared`.
    /// Debe llamarse exactamente una vez, desde `sinkmusicApp.init()`.
    static func createShared() -> DIContainer {
        precondition(shared == nil, "DIContainer.shared ya existe — createShared() debe llamarse una sola vez.")
        let container = DIContainer()
        shared = container
        return container
    }

    // MARK: - Initialization

    init() {
        // EventBus primero: es consumido por todos los demás componentes
        _eventBus = EventBus()
    }

    // MARK: - SwiftData Context

    private var modelContext: ModelContext?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        // Iniciar verificación de autenticación después de configurar
        authViewModel.checkAuth()
    }

    /// Devuelve el `ModelContext` configurado o falla — evita repetir el guard en cada factory.
    private func requireModelContext() -> ModelContext {
        guard let modelContext else {
            fatalError("❌ DIContainer: ModelContext no configurado. Llama a configure(with:) primero.")
        }
        return modelContext
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

    /// Completion handler de sesiones de descarga en segundo plano (iOS). Sin modelContext.
    private(set) lazy var backgroundSessionCompletionService: BackgroundSessionCompletionServiceProtocol = BackgroundSessionCompletionService()

    // MARK: - Auth Module (Facade + Strategy)

    /// Proveedor de autenticación configurado
    private let authProvider: AuthStrategyFactory.Provider = .apple

    /// Estrategia de autenticación (creada según ambiente)
    private lazy var authStrategy: AuthStrategy = {
        AuthStrategyFactory.makeStrategy(for: authProvider)
    }()

    /// Facade de autenticación (interno - no exponer directamente)
    private lazy var authFacade: AuthFacade = {
        AuthFacade(strategy: authStrategy, eventBus: eventBus)
    }()

    /// ViewModel de autenticación (único punto de acceso público)
    private(set) lazy var authViewModel: AuthViewModel = {
        AuthViewModel(facade: authFacade)
    }()

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

    // MARK: - Read Stores (lectura reactiva, SOLID: Interface Segregation por dominio)

    private(set) lazy var homeReadStore: HomeReadStoreProtocol = HomeReadStore(
        libraryUseCases: libraryUseCases,
        playlistUseCases: playlistUseCases,
        modelContext: requireModelContext()
    )

    private(set) lazy var libraryReadStore: LibraryReadStoreProtocol = LibraryReadStore(
        libraryUseCases: libraryUseCases,
        modelContext: requireModelContext()
    )

    private(set) lazy var playlistReadStore: PlaylistReadStoreProtocol = PlaylistReadStore(
        playlistUseCases: playlistUseCases,
        modelContext: requireModelContext()
    )

    private(set) lazy var searchReadStore: SearchReadStoreProtocol = SearchReadStore(
        searchUseCases: searchUseCases,
        modelContext: requireModelContext()
    )

    // MARK: - Shared DataSources

    /// Instancia única de SongLocalDataSource compartida entre todos los repositorios
    /// que la necesiten. Evita múltiples instancias apuntando al mismo ModelContext.
    private lazy var songLocalDataSource: SongLocalDataSource = {
        SongLocalDataSource(modelContext: requireModelContext())
    }()

    // MARK: - Repository Factories

    private func makeSongRepository() -> SongRepositoryProtocol {
        SongRepositoryImpl(localDataSource: songLocalDataSource)
    }

    private func makePlaylistRepository() -> PlaylistRepositoryProtocol {
        let playlistLocalDataSource = PlaylistLocalDataSource(modelContext: requireModelContext())
        return PlaylistRepositoryImpl(
            localDataSource: playlistLocalDataSource,
            songRepository: songRepository,
            songLocalDataSource: songLocalDataSource
        )
    }

    private func makeAudioPlayerRepository() -> AudioPlayerRepositoryProtocol {
        AudioPlayerRepositoryImpl(audioPlayerService: audioPlayerService)
    }

    private func makeCloudStorageRepository() -> CloudStorageRepositoryProtocol {
        let googleDriveDataSource = GoogleDriveDataSource(keychainService: keychainService, eventBus: eventBus)
        let megaDataSource = MegaDataSource(eventBus: eventBus, backgroundSessionCompletion: backgroundSessionCompletionService)
        return CloudStorageRepositoryImpl(
            googleDriveDataSource: googleDriveDataSource,
            megaDataSource: megaDataSource,
            songLocalDataSource: songLocalDataSource,
            credentialsRepository: credentialsRepository
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
            metadataRepository: metadataRepository,
            credentialsRepository: credentialsRepository,
            eventBus: eventBus
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
        LibraryViewModel(libraryUseCases: libraryUseCases, readStore: libraryReadStore)
    }

    /// Factory para PlaylistViewModel
    func makePlaylistViewModel() -> PlaylistViewModel {
        PlaylistViewModel(playlistUseCases: playlistUseCases, readStore: playlistReadStore)
    }

    /// Factory para SearchViewModel
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(readStore: searchReadStore)
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
        HomeViewModel(readStore: homeReadStore)
    }

    /// Factory para DownloadViewModel
    func makeDownloadViewModel() -> DownloadViewModel {
        DownloadViewModel(
            downloadUseCases: downloadUseCases,
            eventBus: eventBus
        )
    }

    /// Factory para AuthViewModel (Facade + Strategy)
    /// Nota: Usar authViewModel directamente en lugar de crear nuevas instancias
    func makeAuthViewModel() -> AuthViewModel {
        authViewModel
    }

    /// Factory para PlayerCoordinator — recibe MetadataCacheViewModel que vive en la capa de UI
    func makePlayerCoordinator(metadataViewModel: MetadataCacheViewModel) -> PlayerCoordinator {
        PlayerCoordinator(metadataViewModel: metadataViewModel)
    }
}
