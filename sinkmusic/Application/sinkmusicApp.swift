//
//  sinkmusicApp.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture + EventBus
//  Usa DIContainer para inyección de dependencias
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "App")

@main
struct sinkmusicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - DIContainer
    // Creado aquí para que sinkmusicApp sea el dueño explícito del ciclo de vida.
    // DIContainer.shared queda registrado para que AppDelegate pueda accederlo.
    private let container: DIContainer
    /// `nil` si SwiftData no pudo abrir el store (ver `modelContainerError`).
    private let modelContainer: ModelContainer?
    private let modelContainerError: String?

    // MARK: - ViewModels creados con DIContainer
    @State private var playerViewModel: PlayerViewModel?
    @State private var libraryViewModel: LibraryViewModel?
    @State private var homeViewModel: HomeViewModel?
    @State private var searchViewModel: SearchViewModel?
    @State private var playlistViewModel: PlaylistViewModel?
    @State private var homePlaylistLayoutViewModel: HomePlaylistLayoutViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    @State private var equalizerViewModel: EqualizerViewModel?
    @State private var downloadViewModel: DownloadViewModel?
    @State private var authViewModel: AuthViewModel?

    // MARK: - UI Cache
    @State private var metadataViewModel = MetadataCacheViewModel()

    // MARK: - Coordinator
    @State private var playerCoordinator: PlayerCoordinator?
    @State private var didConfigureContainer = false

    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Crear e registrar el contenedor antes de que cualquier AppDelegate
        // pueda necesitar DIContainer.shared (p.ej. background URL sessions).
        container = DIContainer.createShared()
        do {
            modelContainer = try ModelContainer(for: SongDTO.self, PlaylistDTO.self, RankingWindowEntryDTO.self)
            modelContainerError = nil
        } catch {
            // Antes: `fatalError` → crash-loop al arrancar. Ahora se muestra `StorageErrorView`.
            modelContainer = nil
            modelContainerError = String(describing: error)
            logger.critical("No se pudo crear el ModelContainer: \(String(describing: error), privacy: .public)")
        }

        // Configurar apariencia del NavigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appDark)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        // Botón de back en blanco
        appearance.setBackIndicatorImage(
            UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal),
            transitionMaskImage: UIImage(systemName: "chevron.left")
        )

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                mainContent
                    .modelContainer(modelContainer)
            } else {
                StorageErrorView(details: modelContainerError ?? "Error desconocido al abrir la base de datos.")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if let authVM = authViewModel {
                    if authVM.isCheckingAuth {
                        // Pantalla de carga mientras verifica autenticación
                        Color.appDark
                            .ignoresSafeArea()
                    } else if authVM.isAuthenticated {
                        // App principal con ViewModels
                        if let playerVM = playerViewModel,
                           let libraryVM = libraryViewModel,
                           let homeVM = homeViewModel,
                           let searchVM = searchViewModel,
                           let playlistVM = playlistViewModel,
                           let homeLayoutVM = homePlaylistLayoutViewModel,
                           let settingsVM = settingsViewModel,
                           let equalizerVM = equalizerViewModel,
                           let downloadVM = downloadViewModel,
                           let coordinator = playerCoordinator {

                            MainAppView()
                                .environment(playerVM)
                                .environment(libraryVM)
                                .environment(homeVM)
                                .environment(searchVM)
                                .environment(playlistVM)
                                .environment(homeLayoutVM)
                                .environment(settingsVM)
                                .environment(equalizerVM)
                                .environment(downloadVM)
                                .environment(metadataViewModel)
                                .environment(authVM)
                                .environment(coordinator)
                        } else {
                            // Fallback mientras se inicializan ViewModels
                            ProgressView("Inicializando...")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.appDark)
                        }
                    } else {
                        LoginView()
                            .environment(authVM)
                            .transition(.opacity)
                    }
                } else {
                    // Fallback mientras se crea AuthViewModel
                    Color.appDark
                        .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authViewModel?.isAuthenticated)
            .task {
                // Configurar DIContainer una sola vez con el contexto compartido
                await configureDIContainer()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Respaldo al pasar a segundo plano: no depende del throttle de timeUpdated
                if newPhase == .background {
                    playerViewModel?.persistCurrentPlaybackState()
                }
            }
    }

    // MARK: - Configuration

    @MainActor
    private func configureDIContainer() async {
        guard !didConfigureContainer, let modelContext = modelContainer?.mainContext else { return }

        // Configurar DIContainer
        container.configure(with: modelContext)

        // Crear ViewModels usando DIContainer
        // AuthViewModel primero para que pueda recibir eventos de autenticación
        authViewModel = container.makeAuthViewModel()

        playerViewModel = container.makePlayerViewModel()
        await playerViewModel?.restoreLastPlaybackState()
        libraryViewModel = container.makeLibraryViewModel()
        homeViewModel = container.makeHomeViewModel()
        searchViewModel = container.makeSearchViewModel()
        playlistViewModel = container.makePlaylistViewModel()
        homePlaylistLayoutViewModel = container.makeHomePlaylistLayoutViewModel()
        settingsViewModel = container.makeSettingsViewModel()
        equalizerViewModel = container.makeEqualizerViewModel()
        downloadViewModel = container.makeDownloadViewModel()
        playerCoordinator = container.makePlayerCoordinator(metadataViewModel: metadataViewModel)

        didConfigureContainer = true
        logger.info("DIContainer configurado correctamente")
    }
}
