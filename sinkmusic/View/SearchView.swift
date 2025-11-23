
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
                    SearchResultRow(
                        song: song,
                        currentlyPlayingID: playerViewModel.currentlyPlayingID,
                        isPlaying: playerViewModel.isPlaying,
                        onTap: { playerViewModel.play(song: song) }
                    )
                    .equatable() // Usar Equatable para evitar re-renderizados innecesarios
                    .id(song.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

struct SearchResultRow: View, Equatable {
    let song: Song
    let currentlyPlayingID: UUID?
    let isPlaying: Bool
    let onTap: () -> Void

    // Implementar Equatable para optimizar re-renderizados
    static func == (lhs: SearchResultRow, rhs: SearchResultRow) -> Bool {
        lhs.song.id == rhs.song.id &&
        lhs.currentlyPlayingID == rhs.currentlyPlayingID &&
        lhs.isPlaying == rhs.isPlaying
    }

    // Usar thumbnail medio optimizado para listas (100x100) en lugar del artwork completo
    private var cachedImage: UIImage? {
        // Preferir el thumbnail medio que es mucho más ligero (< 10KB vs cientos de KB)
        if let thumbnailData = song.artworkMediumThumbnail {
            return UIImage(data: thumbnailData)
        }
        // Fallback al artwork completo si no hay thumbnail (canciones viejas)
        if let artworkData = song.artworkData {
            return UIImage(data: artworkData)
        }
        return nil
    }

    private var isCurrentSongPlaying: Bool {
        currentlyPlayingID == song.id && isPlaying
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork - optimizado para evitar recreación constante
                ArtworkView(image: cachedImage)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrentSongPlaying ? .spotifyGreen : .white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.spotifyLightGray)
                        .lineLimit(1)
                }

                Spacer()

                // Playing indicator
                if isCurrentSongPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(.spotifyGreen)
                        .symbolEffect(.variableColor.iterative.reversing)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentlyPlayingID == song.id ? Color.spotifyGray.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Artwork View (Optimizado)
private struct ArtworkView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
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
        }
    }
}

#Preview {
    PreviewWrapper(
        mainVM: PreviewViewModels.mainVM(),
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { SearchView() }
}
