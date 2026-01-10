import SwiftUI

struct MainAppView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(MetadataCacheViewModel.self) private var metadataViewModel

    @Namespace private var animation

    @State private var currentSongEntity: SongUIModel? = nil
    @State private var songsLookup: [UUID: SongUIModel] = [:]

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
            updateSongsLookup()
        }
        .onChange(of: playerViewModel.currentlyPlayingID) { oldValue, newValue in
            handlePlayingIDChange(newValue)
        }
        .onChange(of: libraryViewModel.songs) { oldValue, newValue in
            handleLibrarySongsChange(newValue)
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
        if let currentSong = currentSongEntity, playerViewModel.showPlayerView {
            PlayerView(
                songs: libraryViewModel.songs,
                currentSong: currentSong,
                namespace: animation
            )
            .zIndex(2)
        }
    }

    @ViewBuilder
    private var miniPlayerView: some View {
        if let currentSong = currentSongEntity,
           playerViewModel.currentlyPlayingID != nil,
           !playerViewModel.showPlayerView {

            PlayerControlsView(
                songID: currentSong.id,
                title: currentSong.title,
                artist: currentSong.artist,
                dominantColor: currentSong.backgroundColor,
                namespace: animation
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 55)
            .zIndex(1)
            .onTapGesture {
                playerViewModel.showPlayerView = true
            }
        }
    }

    private func handlePlayingIDChange(_ newValue: UUID?) {
        if let playingID = newValue {
            if let song = libraryViewModel.songs.first(where: { $0.id == playingID }) {
                metadataViewModel.cacheArtwork(
                    from: song.artworkThumbnail,
                    thumbnail: song.artworkThumbnail
                )
                currentSongEntity = song
            }
        } else {
            metadataViewModel.clearCache()
            currentSongEntity = nil
        }
    }

    private func handleLibrarySongsChange(_ newValue: [SongUIModel]) {
        updateSongsLookup()

        if let playingID = playerViewModel.currentlyPlayingID,
           let updatedSong = newValue.first(where: { $0.id == playingID }) {
            currentSongEntity = updatedSong
        }
    }

    private func updateSongsLookup() {
        songsLookup = Dictionary(uniqueKeysWithValues: libraryViewModel.songs.map { ($0.id, $0) })
    }
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { MainAppView() }
}
