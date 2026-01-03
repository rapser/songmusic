
import SwiftUI
import SwiftData

struct SearchView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Barra de búsqueda
                    SearchBar(text: Binding(
                        get: { viewModel.searchQuery },
                        set: { newValue in
                            viewModel.searchQuery = newValue
                            Task {
                                await viewModel.search()
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Filtros
                    FilterPicker(selectedFilter: Binding(
                        get: {
                            // Mapear SortOption a SearchFilter (legacy)
                            convertToSearchFilter(viewModel.sortOption)
                        },
                        set: { newFilter in
                            let sortOption = convertToSortOption(newFilter)
                            Task {
                                await viewModel.changeSortOption(sortOption)
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Loading State
                    if viewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                    }
                    // Resultados
                    else if viewModel.searchQuery.isEmpty {
                        EmptySearchView()
                    } else if viewModel.searchResults.isEmpty {
                        NoResultsView()
                    } else {
                        SearchResultsList(
                            songs: viewModel.searchResults,
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
        .task {
            // Cargar datos iniciales
            await viewModel.loadAggregations()
            await viewModel.loadRecommendations()
        }
    }

    // MARK: - Helpers para compatibilidad con FilterPicker legacy

    private func convertToSearchFilter(_ sortOption: SortOption) -> SearchFilter {
        switch sortOption {
        case .title: return .all
        case .artist: return .downloaded
        case .playCount: return .notDownloaded
        default: return .all
        }
    }

    private func convertToSortOption(_ filter: SearchFilter) -> SortOption {
        switch filter {
        case .all: return .title
        case .downloaded: return .artist
        case .notDownloaded: return .playCount
        }
    }
}

#Preview {
    PreviewWrapper(
        modelContainer: PreviewData.container(with: PreviewSongs.generate())
    ) { SearchView() }
}
