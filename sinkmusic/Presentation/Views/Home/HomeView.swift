import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]
    @Query private var allSongs: [Song]

    @EnvironmentObject var playerViewModel: PlayerViewModel

    var topSongs: [Song] {
        // Filtrar solo canciones descargadas con playCount > 0
        let downloadedSongs = allSongs.filter { $0.isDownloaded && $0.playCount > 0 }
        // Ordenar por playCount descendente y tomar las primeras 6
        return Array(downloadedSongs.sorted { $0.playCount > $1.playCount }.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        HStack {
                            Text("Inicio")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        // Playlists Grid
                        PlaylistGridView(playlists: Array(playlists.prefix(8)))

                        // Top Songs Carousel
                        TopSongsCarousel(songs: topSongs)

                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    PreviewWrapper(
        playerVM: PreviewViewModels.playerVM(),
        modelContainer: PreviewContainer.shared.container
    ) {
        HomeView()
    }
}
