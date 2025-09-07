import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]

    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Sink Music")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()

                List(songs) { song in
                    SongRow(song: song)
                        .onTapGesture {
                            viewModel.play(song: song)
                        }
                }
                .listStyle(PlainListStyle())
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
    
    // Datos simulados para el preview
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
                    .padding()

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

