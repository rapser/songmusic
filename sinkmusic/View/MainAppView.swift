import SwiftUI
import SwiftData

struct MainAppView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @Namespace private var animation
    
    private var currentSong: Song? {
        songs.first { $0.id == viewModel.playerViewModel.currentlyPlayingID }
    }

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
            }
            .accentColor(.white)
            .environmentObject(viewModel.playerViewModel)

            // PlayerView completo
            if let currentSong = currentSong, viewModel.playerViewModel.showPlayerView {
                PlayerView(
                    songs: songs,
                    currentSong: currentSong,
                    namespace: animation
                )
                .transition(.move(edge: .bottom))
            }

            // Mini Player
            if let currentSong = currentSong,
               viewModel.playerViewModel.currentlyPlayingID != nil,
               !viewModel.isScrolling,
               !viewModel.playerViewModel.showPlayerView {
                PlayerControlsView(song: currentSong, namespace: animation)
                    .padding(.bottom, 60)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewModel.playerViewModel.showPlayerView = true
                        }
                    }
                    .transition(.move(edge: .bottom))
            }
        }
        .environmentObject(viewModel)
    }
}

#Preview {
    MainAppViewPreviewWrapper()
}

private struct MainAppViewPreviewWrapper: View {
    private let container: ModelContainer
    private let mainViewModel: MainViewModel

    init() {
        // Crear container en memoria
        if let testContainer = try? ModelContainer(
            for: Song.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ) {
            let context = testContainer.mainContext
            
            // Insertar canciones mock
            [
                Song(title: "Song 1", artist: "Artist 1", fileID: "file1"),
                Song(title: "Song 2", artist: "Artist 2", fileID: "file2"),
                Song(title: "Song 3", artist: "Artist 3", fileID: "file3")
            ].forEach { context.insert($0) }

            self.container = testContainer
        }
        else {
            fatalError("❌ Failed to create container")
        }

        self.mainViewModel = MainViewModel(playerViewModel: PlayerViewModel())
    }

    var body: some View {
        MainAppView()
            .modelContainer(container)
            .environmentObject(mainViewModel)
    }
}
