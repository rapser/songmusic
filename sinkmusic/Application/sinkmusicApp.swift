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
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var songListViewModel = SongListViewModel()
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingAuth {
                    // Mostrar pantalla en blanco mientras se verifica la autenticación
                    Color.appDark
                        .ignoresSafeArea()
                } else if authManager.isAuthenticated {
                    MainAppView()
                        .environmentObject(viewModel)
                        .environmentObject(viewModel.playerViewModel)
                        .environmentObject(songListViewModel)
                        .environmentObject(authManager)
                        .onAppear {
                            // Configurar CarPlay cuando la app aparece
                            CarPlayService.shared.configure(with: viewModel.playerViewModel)
                        }
                } else {
                    LoginView(authManager: authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .task {
                // Configurar el ModelContext compartido en el ViewModel
                // Esto permite que las descargas continúen incluso si cambias de pantalla
                if let modelContext = try? ModelContext(ModelContainer(for: Song.self, Playlist.self)) {
                    songListViewModel.configure(with: modelContext)
                }
            }
        }
        .modelContainer(for: [Song.self, Playlist.self])
    }
}
