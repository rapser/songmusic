import SwiftUI

struct MainAppView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(MetadataCacheViewModel.self) private var metadataViewModel

    @Namespace private var animation

    @State private var currentSong: SongUI? = nil
    @State private var songsLookup: [UUID: SongUI] = [:]

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
        if let currentSong = currentSong, playerViewModel.showPlayerView {
            PlayerView(
                songs: libraryViewModel.songs,
                currentSong: currentSong,
                namespace: animation
            )
            .zIndex(2)
            .task(id: currentSong.id) {
                if currentSong.dominantColor == nil, currentSong.artworkThumbnail != nil {
                    await libraryViewModel.persistDominantColorIfNeeded(songID: currentSong.id, artworkData: currentSong.artworkThumbnail)
                }
            }
        }
    }

    @ViewBuilder
    private var miniPlayerView: some View {
        if let currentSong = currentSong,
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
            .task(id: currentSong.id) {
                if currentSong.dominantColor == nil, currentSong.artworkThumbnail != nil {
                    await libraryViewModel.persistDominantColorIfNeeded(songID: currentSong.id, artworkData: currentSong.artworkThumbnail)
                }
            }
        }
    }

    private func handlePlayingIDChange(_ newValue: UUID?) {
        if let playingID = newValue {
            guard let song = libraryViewModel.songs.first(where: { $0.id == playingID }) else { return }
            currentSong = song
            // Mini player: thumbnail pequeño (32x32) es suficiente.
            metadataViewModel.cacheArtwork(from: nil, thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail)
            // Player grande: cargar artwork en resolución completa en segundo plano.
            Task {
                let fullArtwork = await libraryViewModel.getArtworkData(songID: playingID)
                await MainActor.run {
                    metadataViewModel.cacheArtwork(
                        from: fullArtwork,
                        thumbnail: song.artworkSmallThumbnail ?? song.artworkThumbnail
                    )
                }
            }
        } else {
            metadataViewModel.clearCache()
            currentSong = nil
        }
    }

    private func handleLibrarySongsChange(_ newValue: [SongUI]) {
        updateSongsLookup()

        if let playingID = playerViewModel.currentlyPlayingID,
           let updatedSong = newValue.first(where: { $0.id == playingID }) {
            currentSong = updatedSong
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
