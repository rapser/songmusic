
import SwiftUI
import SwiftData

struct MainAppView: View {
    @StateObject private var viewModel = MainViewModel()
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @State private var showPlayerView = false
    @Namespace private var animation

    private var currentSong: Song? {
        songs.first { $0.id == viewModel.currentlyPlayingID }
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
                    .tabItem {
                        Label("Inicio", systemImage: "house.fill")
                    }

                SearchView()
                    .tabItem {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }

                LibraryView()
                    .tabItem {
                        Label("Biblioteca", systemImage: "books.vertical.fill")
                    }
            }
            .accentColor(.white)

            // PlayerView completo (pantalla grande)
            if showPlayerView, let currentSong = currentSong {
                PlayerView(
                    songs: songs,
                    currentSong: currentSong,
                    namespace: animation,
                    showPlayerView: $showPlayerView
                )
            }

            // Mini Player
            if let currentSong = currentSong, !showPlayerView, !viewModel.isScrolling {
                PlayerControlsView(song: currentSong, namespace: animation)
                    .padding(.bottom, 60)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showPlayerView = true
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
    var body: some View {
        Group {
            if let container = try? ModelContainer(
                for: Song.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ) {
                let context = container.mainContext
                
                // Insertar canciones de ejemplo
                let _ = [
                    Song(title: "Song 1", artist: "Artist 1", fileID: "file1"),
                    Song(title: "Song 2", artist: "Artist 2", fileID: "file2"),
                    Song(title: "Song 3", artist: "Song 3", fileID: "file3")
                ].map { context.insert($0) }
                
                MainAppView()
                    .modelContainer(container)
            } else {
                Text("Failed to create container")
            }
        }
    }
}

