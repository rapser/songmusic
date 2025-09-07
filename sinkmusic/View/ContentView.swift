import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]

    @EnvironmentObject var viewModel: MainViewModel
    @State private var showPlayerView = false
    
    private var currentSong: Song? {
        songs.first { $0.id == viewModel.currentlyPlayingID }
    }

    var body: some View {
        NavigationView {
            VStack {
                List(songs) { song in
                    SongRow(song: song)
                }
                
                if let currentSong = currentSong {
                    PlayerControlsView(song: currentSong)
                        .padding(.bottom, 8)
                        .onTapGesture { showPlayerView = true }
                }
            }
            .navigationTitle("Sink Music")
            .onAppear {
                viewModel.syncLibraryWithCatalog(modelContext: modelContext)
            }
            .sheet(isPresented: $showPlayerView) {
                if let currentSong = currentSong {
                    PlayerView(songs: songs, currentSong: currentSong)
                }
            }
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(for: Song.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}
