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
    @State private var dragOffset: CGFloat = 0
    @State private var isClosingBanner = false

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.spotifyGray)
        
        let textAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(Color.spotifyLightGray)]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.spotifyLightGray)
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
                SettingsView()
                    .tabItem { Label("Configuración", systemImage: "gearshape.fill") }
            }
            .accentColor(.white)

            // PlayerView completo
            if let currentSong = currentSong, playerViewModel.showPlayerView {
                PlayerView(
                    songs: songs,
                    currentSong: currentSong,
                    namespace: animation
                )
                .transition(.move(edge: .bottom))
            }

            // Mini Player
            if let currentSong = currentSong,
               playerViewModel.currentlyPlayingID != nil,
               !playerViewModel.showPlayerView,
               !isClosingBanner {

                PlayerControlsView(song: currentSong, namespace: animation)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                    .offset(x: dragOffset)
                    .opacity(dragOffset < -50 ? 1 - (abs(dragOffset) - 50.0) / 100 : 1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            playerViewModel.showPlayerView = true
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Solo permitir arrastre hacia la izquierda
                                if value.translation.width < 0 {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                // Si se arrastró más de 150px, cerrar el player
                                if value.translation.width < -150 {
                                    // PRIMERO marcar que estamos cerrando (esto oculta el banner inmediatamente)
                                    isClosingBanner = true

                                    // Animar la salida
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        dragOffset = -UIScreen.main.bounds.width
                                    }

                                    // Luego detener el player y resetear
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        playerViewModel.stop()
                                        dragOffset = 0
                                        isClosingBanner = false
                                    }
                                } else {
                                    // Regresar a la posición original
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .onAppear {
            updateCurrentSong()
            updateDebugInfo()
            playerViewModel.updateSongsList(songs)
        }
        .onChange(of: playerViewModel.currentlyPlayingID) {
            updateCurrentSong()
            updateDebugInfo()
        }
        .onChange(of: playerViewModel.showPlayerView) {
            updateDebugInfo()
        }
        .onChange(of: playerViewModel.isPlaying) {
            updateDebugInfo()
        }
        .onChange(of: songs) {
            updateCurrentSong()
            playerViewModel.updateSongsList(songs)
            print("🔄 Songs updated: \(songs.count)")
        }
    }
    
    private func updateCurrentSong() {
        if let playingID = playerViewModel.currentlyPlayingID {
            currentSong = songs.first { $0.id == playingID }
            print("🔍 Current song: \(currentSong?.title ?? "nil")")
        } else {
            currentSong = nil
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

