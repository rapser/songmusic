import SwiftUI

struct HomeView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(LibraryViewModel.self) private var libraryViewModel

    @State private var didLoadInitially = false

    var topSongs: [SongUI] {
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
                            // Playlists Grid — ya viene curada (orden + visibilidad) desde Ajustes
                            PlaylistGridView(playlists: viewModel.playlists)

                            // Top Songs Carousel
                            TopSongsCarousel(songs: topSongs)

                            // Playlists más escuchadas (horizontal, máx. 10)
                            PlaylistsCarouselView(playlists: Array(viewModel.mostPlayedPlaylists.prefix(10)))
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await libraryViewModel.syncLibraryWithCatalog()
                    await viewModel.refresh()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            // Cargar datos al aparecer la vista
            await viewModel.loadData()
            didLoadInitially = true
        }
        .onAppear {
            // Al volver a la pestaña Inicio (p. ej. tras curar playlists en Ajustes),
            // refrescar en silencio. El `.task` de arriba ya cubre la primera aparición.
            guard didLoadInitially else { return }
            Task { await viewModel.refreshQuietly() }
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
