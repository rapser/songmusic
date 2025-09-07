import SwiftUI
import SwiftData

// PreferenceKey para medir el scroll
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]
    @EnvironmentObject var viewModel: MainViewModel // Keep MainViewModel for isScrolling
    @StateObject private var songListViewModel = SongListViewModel() // New StateObject

    @State private var lastOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

            VStack {
                Text("Sink Music")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(songs) { song in
                            SongRow(song: song)
                                .environmentObject(songListViewModel) // Pass SongListViewModel
                                .onTapGesture {
                                    viewModel.playerViewModel.play(song: song)
                                }
                        }
                    }

                    // GeometryReader dentro del contenido que se mueve
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                    }
                    .frame(height: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newOffset in
                let delta = newOffset - lastOffset

                if delta > 0 {
                    // Scroll hacia abajo -> ocultar
                    viewModel.isScrolling = true
                } else if delta < 0 {
                    // Scroll hacia arriba -> mostrar
                    viewModel.isScrolling = false
                }

                lastOffset = newOffset
                print("Scroll Offset: \(newOffset), delta: \(delta), isScrolling: \(viewModel.isScrolling)")
            }
        }
        .onAppear {
            viewModel.syncLibraryWithCatalog(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentViewPreviewWrapper()
}

private struct ContentViewPreviewWrapper: View {
    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var songListViewModel = SongListViewModel()
    @Environment(\.modelContext) private var modelContext // <- aquí obtienes el contexto de SwiftData

    // Datos de ejemplo
    private let exampleSongs = [
        Song(id: UUID(), title: "Song 1", artist: "Artist 1", fileID: "file1", isDownloaded: true),
        Song(id: UUID(), title: "Song 2", artist: "Artist 2", fileID: "file2", isDownloaded: false),
        Song(id: UUID(), title: "Song 3", artist: "Artist 3", fileID: "file3", isDownloaded: false)
    ]

    var body: some View {
        ContentView()
            .environmentObject(mainViewModel)
            .environmentObject(songListViewModel)
            .modelContainer(for: Song.self, inMemory: true)
            .onAppear {
                for song in exampleSongs {
                    modelContext.insert(song)
                }
            }
    }
}
