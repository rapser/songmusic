
import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    @Query(sort: [SortDescriptor(\Song.title)]) private var songs: [Song]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spotifyBlack.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Barra de búsqueda
                    SearchBar(text: $searchViewModel.searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Filtros
                    FilterPicker(selectedFilter: $searchViewModel.selectedFilter)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // Resultados
                    if searchViewModel.searchText.isEmpty {
                        EmptySearchView()
                    } else if searchViewModel.filteredSongs.isEmpty {
                        NoResultsView()
                    } else {
                        SearchResultsList(
                            songs: searchViewModel.filteredSongs,
                            playerViewModel: playerViewModel
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Buscar")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            searchViewModel.updateSongs(songs)
        }
        .onChange(of: songs) {
            searchViewModel.updateSongs(songs)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.spotifyLightGray)

            TextField("", text: $text, prompt: Text("¿Qué quieres escuchar?").foregroundColor(.spotifyLightGray))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.spotifyLightGray)
                }
            }
        }
        .padding(12)
        .background(Color.spotifyGray)
        .cornerRadius(8)
    }
}

// MARK: - Filter Picker
struct FilterPicker: View {
    @Binding var selectedFilter: SearchViewModel.SearchFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchViewModel.SearchFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .spotifyBlack : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.spotifyGreen : Color.spotifyGray)
                .cornerRadius(20)
        }
    }
}

// MARK: - Empty State
struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.spotifyLightGray)

            Text("Encuentra tu música")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Busca canciones, artistas o álbumes")
                .font(.subheadline)
                .foregroundColor(.spotifyLightGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - No Results
struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.spotifyLightGray)

            Text("No se encontraron resultados")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Intenta buscar algo diferente")
                .font(.subheadline)
                .foregroundColor(.spotifyLightGray)

            Spacer()
        }
    }
}

// MARK: - Results List
struct SearchResultsList: View {
    let songs: [Song]
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(songs) { song in
                    SearchResultRow(song: song, playerViewModel: playerViewModel)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

struct SearchResultRow: View {
    let song: Song
    @ObservedObject var playerViewModel: PlayerViewModel

    var isPlaying: Bool {
        playerViewModel.currentlyPlayingID == song.id && playerViewModel.isPlaying
    }

    var body: some View {
        Button {
            playerViewModel.play(song: song)
        } label: {
            HStack(spacing: 12) {
                // Artwork
                if let artworkData = song.artworkData,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.spotifyGray)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.spotifyLightGray)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isPlaying ? .spotifyGreen : .white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.spotifyLightGray)
                        .lineLimit(1)
                }

                Spacer()

                // Playing indicator
                if isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(.spotifyGreen)
                        .symbolEffect(.variableColor.iterative.reversing)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(playerViewModel.currentlyPlayingID == song.id ? Color.spotifyGray.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { SearchView() }
}
