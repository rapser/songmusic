import SwiftUI

struct MainAppView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(PlayerCoordinator.self) private var playerCoordinator

    @Namespace private var animation

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor =  UIColor(Color.appGray)

        let textAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(Color.textGray)]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]

        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textGray)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = textAttributes

        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .white
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedTextAttributes

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mainTabView
            fullPlayerView
            miniPlayerView
        }
        .task {
            playerCoordinator.onLibrarySongsChanged(libraryViewModel.songs, currentlyPlayingID: playerViewModel.currentlyPlayingID)
            // Necesario también aquí (no solo en el .onChange de abajo): si se restauró una
            // canción al abrir la app, `currentlyPlayingID` ya viene fijado antes de que esta
            // vista se monte, así que el .onChange nunca ve un cambio para ese valor inicial
            // y el artwork no se cargaba, mostrando solo el placeholder por defecto.
            await playerCoordinator.onPlayingIDChanged(playerViewModel.currentlyPlayingID, libraryViewModel: libraryViewModel)
        }
        .onChange(of: playerViewModel.currentlyPlayingID) { _, newValue in
            Task { await playerCoordinator.onPlayingIDChanged(newValue, libraryViewModel: libraryViewModel) }
        }
        .onChange(of: libraryViewModel.songs) { _, newValue in
            playerCoordinator.onLibrarySongsChanged(newValue, currentlyPlayingID: playerViewModel.currentlyPlayingID)
            // La biblioteca puede terminar de cargar DESPUÉS del arranque en frío (la
            // canción restaurada aún no estaba en `songsLookup` en el .task de arriba).
            // Idempotente: si el artwork ya se cargó para esta canción, no hace nada.
            Task { await playerCoordinator.onPlayingIDChanged(playerViewModel.currentlyPlayingID, libraryViewModel: libraryViewModel) }
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }
            SearchView()
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            LibraryView()
                .tabItem { Label("Biblioteca", systemImage: "books.vertical.fill") }
            NavigationStack {
                SettingsView()
            }
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .accentColor(.white)
    }

    @ViewBuilder
    private var fullPlayerView: some View {
        if let song = playerCoordinator.currentSong, playerViewModel.showPlayerView {
            PlayerView(
                songs: libraryViewModel.songs,
                currentSong: song,
                namespace: animation
            )
            .zIndex(2)
            .task(id: song.id) {
                if song.dominantColor == nil, song.artworkThumbnail != nil {
                    await libraryViewModel.persistDominantColorIfNeeded(songID: song.id, artworkData: song.artworkThumbnail)
                }
            }
        }
    }

    @ViewBuilder
    private var miniPlayerView: some View {
        if let song = playerCoordinator.currentSong,
           playerViewModel.currentlyPlayingID != nil,
           !playerViewModel.showPlayerView {

            PlayerControlsView(
                songID: song.id,
                title: song.title,
                artist: song.artist,
                dominantColor: song.backgroundColor,
                namespace: animation
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 55)
            .zIndex(1)
            .onTapGesture {
                playerViewModel.showPlayerView = true
            }
            .task(id: song.id) {
                if song.dominantColor == nil, song.artworkThumbnail != nil {
                    await libraryViewModel.persistDominantColorIfNeeded(songID: song.id, artworkData: song.artworkThumbnail)
                }
            }
        }
    }
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { MainAppView() }
}
