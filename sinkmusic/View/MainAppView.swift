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

            // PlayerView completo
            if let currentSong = currentSong, playerViewModel.showPlayerView {
                PlayerView(
                    songs: songs,
                    currentSong: currentSong,
                    namespace: animation
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .bottom)
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .bottom)
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .opacity)
                    )
                )
                .zIndex(2)
            }

            // Mini Player
            if let currentSong = currentSong,
               playerViewModel.currentlyPlayingID != nil,
               !playerViewModel.showPlayerView {

                PlayerControlsView(song: currentSong, namespace: animation)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 55)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .bottom)
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .opacity),
                            removal: .scale(scale: 1.05, anchor: .bottom)
                                .combined(with: .opacity)
                        )
                    )
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            playerViewModel.showPlayerView = true
                        }
                    }
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
        }
    }
    
    private func updateCurrentSong() {
        if let playingID = playerViewModel.currentlyPlayingID {
            currentSong = songs.first { $0.id == playingID }
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

