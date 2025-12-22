import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Song> { $0.isDownloaded }, sort: [SortDescriptor(\Song.title)])
    private var downloadedSongs: [Song]

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel
    
    @State private var songForPlaylistSheet: Song?

    var body: some View {
        let playlistViewModel = PlaylistViewModel(modelContext: modelContext)
        
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("App Music")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Subtitle con contador
                HStack {
                    Text("\(downloadedSongs.count) canciones descargadas")
                        .font(.subheadline)
                        .foregroundColor(.textGray)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Lista de canciones descargadas
                if downloadedSongs.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.textGray)

                        VStack(spacing: 8) {
                            Text("No hay canciones descargadas")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("Ve a Configuración para descargar música")
                                .font(.system(size: 14))
                                .foregroundColor(.textGray)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10, pinnedViews: []) {
                            ForEach(downloadedSongs) { song in
                                SongRow(song: song, songQueue: downloadedSongs, showAddToPlaylistForSong: $songForPlaylistSheet)
                            }
                        }
                        .padding(.bottom, 80) // Espacio para el mini player
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .sheet(item: $songForPlaylistSheet) { song in
            AddToPlaylistView(viewModel: playlistViewModel, song: song)
        }
        .task {
            // Sincronizar automáticamente al cargar la vista
            libraryViewModel.syncLibraryWithCatalog(modelContext: modelContext)
        }
    }
}

#Preview {
    PreviewWrapper(
        libraryVM: PreviewViewModels.libraryVM(),
        songListVM: PreviewViewModels.songListVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { HomeView() }
}
