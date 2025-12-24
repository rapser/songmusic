//
//  sinkmusicApp.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI
import SwiftData

@main
struct sinkmusicApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var songListViewModel = SongListViewModel()
    @StateObject private var metadataViewModel = MetadataCacheViewModel()
    @StateObject private var equalizerViewModel = EqualizerViewModel()
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
                    // Mostrar pantalla en blanco mientras se verifica la autenticación
                    Color.appDark
                        .ignoresSafeArea()
                } else if authManager.isAuthenticated {
                    MainAppView()
                        .environmentObject(libraryViewModel)
                        .environmentObject(playerViewModel)
                        .environmentObject(songListViewModel)
                        .environmentObject(metadataViewModel)
                        .environmentObject(equalizerViewModel)
                        .environmentObject(authManager)
                        .onAppear {
                            // Configurar CarPlay cuando la app aparece
                            CarPlayService.shared.configure(with: playerViewModel)
                        }
                } else {
                    LoginView(authManager: authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .task {
                // Configurar el ModelContext compartido en los ViewModels
                // Esto permite que las descargas continúen y las estadísticas se actualicen
                if let modelContext = try? ModelContext(ModelContainer(for: Song.self, Playlist.self)) {
                    songListViewModel.configure(with: modelContext)
                    playerViewModel.configure(with: modelContext)
                }
            }
        }
        .modelContainer(for: [Song.self, Playlist.self])
    }
}
