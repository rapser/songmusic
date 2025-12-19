import SwiftUI
import SwiftData

struct MainAppView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @Namespace private var animation

    @State private var currentSong: Song? = nil
    @State private var debugMessage = ""
    @State private var showDebugInfo = true
    @State private var songsLookup: [UUID: Song] = [:]

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
                ContentView()
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

            // PlayerView completo - Animación suave como Spotify
            if let currentSong = currentSong, playerViewModel.showPlayerView {
                PlayerView(
                    songs: songs,
                    currentSong: currentSong,
                    namespace: animation
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)
                    )
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: playerViewModel.showPlayerView)
                .zIndex(2)
            }

            // Mini Player - Aparición rápida como Spotify
            if let currentSong = currentSong,
               playerViewModel.currentlyPlayingID != nil,
               !playerViewModel.showPlayerView {

                PlayerControlsView(song: currentSong, namespace: animation)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 55)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .opacity),
                            removal: .move(edge: .bottom)
                                .combined(with: .opacity)
                        )
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: playerViewModel.currentlyPlayingID)
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            playerViewModel.showPlayerView = true
                        }
                    }
            }
        }
        .task {
            // Crear lookup dictionary una vez al inicio
            updateSongsLookup()
            playerViewModel.updateSongsList(songs)
        }
        .onChange(of: playerViewModel.currentlyPlayingID) { oldValue, newValue in
            // Usar lookup O(1) en lugar de first O(n)
            if let playingID = newValue {
                currentSong = songsLookup[playingID]
            } else {
                currentSong = nil
            }
            updateDebugInfo()
        }
        .onChange(of: songs) { oldValue, newValue in
            // Actualizar lookup solo cuando cambian las canciones
            updateSongsLookup()
            playerViewModel.updateSongsList(newValue)
        }
    }

    private func updateSongsLookup() {
        // O(n) solo cuando cambian las canciones, no en cada render
        songsLookup = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })

        // Actualizar currentSong con el nuevo lookup
        if let playingID = playerViewModel.currentlyPlayingID {
            currentSong = songsLookup[playingID]
        }
    }
    
    private func updateDebugInfo() {
        debugMessage = """
        Song: \(currentSong?.title.prefix(15) ?? "nil")
        ID: \(playerViewModel.currentlyPlayingID?.uuidString.prefix(8) ?? "nil")
        Playing: \(playerViewModel.isPlaying)
        ShowPlayer: \(playerViewModel.showPlayerView)
        """
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { MainAppView() }
}

