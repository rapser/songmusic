//
//  sinkmusicApp.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  Usa DIContainer para inyección de dependencias
//

import SwiftUI
import SwiftData

@main
struct sinkmusicApp: App {
    // MARK: - DIContainer
    @MainActor
    private let container = DIContainer.shared

    // MARK: - ViewModels creados con DIContainer
    @State private var playerViewModel: PlayerViewModel?
    @State private var libraryViewModel: LibraryViewModel?
    @State private var homeViewModel: HomeViewModel?
    @State private var searchViewModel: SearchViewModel?
    @State private var playlistViewModel: PlaylistViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    @State private var equalizerViewModel: EqualizerViewModel?
    @State private var downloadViewModel: DownloadViewModel?

    // MARK: - UI Cache & Legacy Services
    @State private var metadataViewModel = MetadataCacheViewModel()
    @StateObject private var authManager = AuthenticationManager.shared

    init() {
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
            Group {
                if authManager.isCheckingAuth {
                    // Pantalla de carga mientras verifica autenticación
                    Color.appDark
                        .ignoresSafeArea()
                } else if authManager.isAuthenticated {
                    // App principal con ViewModels
                    if let playerVM = playerViewModel,
                       let libraryVM = libraryViewModel,
                       let homeVM = homeViewModel,
                       let searchVM = searchViewModel,
                       let playlistVM = playlistViewModel,
                       let settingsVM = settingsViewModel,
                       let equalizerVM = equalizerViewModel,
                       let downloadVM = downloadViewModel {

                        MainAppView()
                            .environment(playerVM)
                            .environment(libraryVM)
                            .environment(homeVM)
                            .environment(searchVM)
                            .environment(playlistVM)
                            .environment(settingsVM)
                            .environment(equalizerVM)
                            .environment(downloadVM)
                            .environment(metadataViewModel)
                            .environmentObject(authManager)
                            .onAppear {
                                // Configurar CarPlay cuando la app aparece
                                CarPlayService.shared.configure(with: playerVM)
                            }
                    } else {
                        // Fallback mientras se inicializan ViewModels
                        ProgressView("Inicializando...")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.appDark)
                    }
                } else {
                    LoginView(authManager: authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .task {
                // Configurar DIContainer con ModelContext
                await configureDIContainer()
            }
        }
        .modelContainer(for: [SongDTO.self, PlaylistDTO.self])
    }

    // MARK: - Configuration

    @MainActor
    private func configureDIContainer() async {
        do {
            // Crear ModelContainer y ModelContext
            let modelContainer = try ModelContainer(for: SongDTO.self, PlaylistDTO.self)
            let modelContext = ModelContext(modelContainer)

            // Configurar DIContainer
            container.configure(with: modelContext)

            // Crear ViewModels usando DIContainer
            playerViewModel = container.makePlayerViewModel()
            libraryViewModel = container.makeLibraryViewModel()
            homeViewModel = container.makeHomeViewModel()
            searchViewModel = container.makeSearchViewModel()
            playlistViewModel = container.makePlaylistViewModel()
            settingsViewModel = container.makeSettingsViewModel()
            equalizerViewModel = container.makeEqualizerViewModel()
            downloadViewModel = container.makeDownloadViewModel()

            print("✅ DIContainer configurado correctamente")

        } catch {
            print("❌ Error al configurar DIContainer: \(error)")
        }
    }
}
