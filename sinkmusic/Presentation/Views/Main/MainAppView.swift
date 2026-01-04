import SwiftUI

struct MainAppView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel
    @Environment(MetadataCacheViewModel.self) private var metadataViewModel

    @Namespace private var animation

    @State private var currentSongEntity: SongEntity? = nil
    @State private var songsLookup: [UUID: SongEntity] = [:]

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

            // PlayerView completo - Aparición instantánea
            if let currentSong = currentSongEntity, playerViewModel.showPlayerView {
                PlayerView(
                    songs: libraryViewModel.songs,
                    currentSong: currentSong,
                    namespace: animation
                )
                .zIndex(2)
            }

            // Mini Player - Aparición instantánea como Spotify
            if let currentSong = currentSongEntity,
               playerViewModel.currentlyPlayingID != nil,
               !playerViewModel.showPlayerView {

                PlayerControlsView(
                    songID: currentSong.id,
                    title: currentSong.title,
                    artist: currentSong.artist,
                    dominantColor: currentSong.dominantColor,
                    namespace: animation
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 55)
                .zIndex(1)
                .onTapGesture {
                    // Sin animación - mostrar instantáneamente
                    playerViewModel.showPlayerView = true
                }
            }
        }
        .task {
            updateSongsLookup()
        }
        .onChange(of: playerViewModel.currentlyPlayingID) { oldValue, newValue in
            if let playingID = newValue {
                // Buscar en la library en lugar del lookup para asegurar datos frescos
                if let song = libraryViewModel.songs.first(where: { $0.id == playingID }) {
                    metadataViewModel.cacheArtwork(
                        from: song.artworkData,
                        thumbnail: song.artworkThumbnail
                    )
                    currentSongEntity = song
                }
            } else {
                metadataViewModel.clearCache()
                currentSongEntity = nil
            }
        }
        .onChange(of: libraryViewModel.songs) { oldValue, newValue in
            updateSongsLookup()

            // Actualizar currentSong si la canción actual cambió en la biblioteca
            if let playingID = playerViewModel.currentlyPlayingID,
               let updatedSong = newValue.first(where: { $0.id == playingID }) {
                currentSongEntity = updatedSong
            }
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
