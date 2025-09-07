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
    @EnvironmentObject var viewModel: MainViewModel

    @State private var lastScrollOffset: CGFloat = 0

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
                                .onTapGesture {
                                    viewModel.play(song: song)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newOffset in
                    let offsetChange = newOffset - lastScrollOffset
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isScrolling = offsetChange > 0
                    }
                    lastScrollOffset = newOffset
                }
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
    @StateObject private var viewModel = MainViewModel()
    
    private let exampleSongs = [
        Song(id: UUID(), title: "Song 1", artist: "Artist 1", fileID: "file1", isDownloaded: false),
        Song(id: UUID(), title: "Song 2", artist: "Artist 2", fileID: "file2", isDownloaded: false),
        Song(id: UUID(), title: "Song 3", artist: "Artist 3", fileID: "file3", isDownloaded: false)
    ]
    
    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Sink Music")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                List(exampleSongs) { song in
                    SongRow(song: song)
                        .onTapGesture {
                            viewModel.play(song: song)
                        }
                }
                .listStyle(PlainListStyle())
            }
        }
        .environmentObject(viewModel)
    }
}
