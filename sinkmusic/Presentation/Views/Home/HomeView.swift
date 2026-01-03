import SwiftUI
import SwiftData

struct HomeView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel

    var topSongs: [SongEntity] {
        // Ya viene ordenado por playCount desde el ViewModel
        Array(viewModel.mostPlayedSongs.prefix(6))
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

                        // Loading State
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding()
                        } else {
                            // Playlists Grid
                            PlaylistGridView(playlists: Array(viewModel.playlists.prefix(8)))

                            // Top Songs Carousel
                            TopSongsCarousel(songs: topSongs)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            // Cargar datos al aparecer la vista
            await viewModel.loadData()
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
