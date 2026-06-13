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
        }
        .onChange(of: playerViewModel.currentlyPlayingID) { _, newValue in
            Task { await playerCoordinator.onPlayingIDChanged(newValue, libraryViewModel: libraryViewModel) }
        }
        .onChange(of: libraryViewModel.songs) { _, newValue in
            playerCoordinator.onLibrarySongsChanged(newValue, currentlyPlayingID: playerViewModel.currentlyPlayingID)
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
                .tabItem { Label("Configuración", systemImage: "gearshape.fill") }
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
