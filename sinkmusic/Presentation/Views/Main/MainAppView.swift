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
        // El coordinador necesita las dos cosas a la vez —la biblioteca y qué suena—, y
        // cualquiera de las dos puede llegar primero. En vez de tres llamadas distintas
        // repartidas por los tres disparadores, hay **una** función y tres motivos para
        // invocarla; es idempotente, así que llamarla de más no cuesta nada.
        .task { await syncPlayerWithLibrary() }
        .onChange(of: playerViewModel.currentlyPlayingID) { _, _ in
            Task { await syncPlayerWithLibrary() }
        }
        .onChange(of: libraryViewModel.songs) { _, newValue in
            Task { await syncPlayerWithLibrary() }
            stopPlaybackIfCurrentSongLostItsDownload(in: newValue)
        }
    }

    /// Pone al coordinador al día con la biblioteca y con la canción en curso.
    ///
    /// Los tres disparadores son distintos de verdad, y por eso siguen los tres: al montar
    /// la vista (`currentlyPlayingID` puede venir ya fijado de una sesión restaurada, así
    /// que el `.onChange` nunca vería ese valor inicial), al cambiar de canción, y cuando la
    /// biblioteca termina de cargar después del arranque en frío (la canción restaurada
    /// todavía no estaba en `songsLookup`).
    private func syncPlayerWithLibrary() async {
        playerCoordinator.onLibrarySongsChanged(
            libraryViewModel.songs,
            currentlyPlayingID: playerViewModel.currentlyPlayingID
        )
        await playerCoordinator.onPlayingIDChanged(
            playerViewModel.currentlyPlayingID,
            libraryViewModel: libraryViewModel
        )
    }

    /// Si la canción en curso dejó de estar descargada (p. ej. "Eliminar todas las
    /// descargas" en Ajustes), su archivo local ya no existe: detener y limpiar el
    /// mini-reproductor.
    ///
    /// Solo cuando la canción **sigue** en la biblioteca pero sin descarga, para no
    /// interferir con la carga inicial ni con un borrado total. Va solo en el cambio de
    /// biblioteca a propósito: dispararlo al cambiar de canción podría detener una
    /// reproducción recién iniciada si la lista aún no se ha refrescado.
    private func stopPlaybackIfCurrentSongLostItsDownload(in songs: [SongUI]) {
        guard let playingID = playerViewModel.currentlyPlayingID,
              let playingSong = songs.first(where: { $0.id == playingID }),
              !playingSong.isDownloaded else { return }

        Task { await playerViewModel.stop() }
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
