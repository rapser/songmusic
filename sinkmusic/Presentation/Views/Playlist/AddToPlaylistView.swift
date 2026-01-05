//
//  AddToPlaylistView.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  No SwiftData dependency
//

import SwiftUI

struct AddToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistViewModel.self) private var viewModel

    let song: SongEntity

    @State private var searchText = ""

    var filteredPlaylists: [PlaylistEntity] {
        if searchText.isEmpty {
            return viewModel.playlists
        } else {
            return viewModel.playlists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Agregar a playlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        closeButton
                    }
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                newPlaylistButton

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)

                playlistsList
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textGray)

            TextField("Buscar playlist", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textGray)
                }
            }
        }
        .padding(12)
        .background(Color.appGray)
        .cornerRadius(8)
    }

    private var newPlaylistButton: some View {
        Button(action: {
            // TODO: Implement create playlist flow
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGray)
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                Text("Nueva playlist")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.clear)
        }
    }

    @ViewBuilder
    private var playlistsList: some View {
        if filteredPlaylists.isEmpty {
            emptyState
        } else {
            playlistsScrollView
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundColor(.textGray)

            Text(searchText.isEmpty ? "No hay playlists" : "No se encontraron playlists")
                .font(.system(size: 16))
                .foregroundColor(.textGray)

            Spacer()
        }
    }

    private var playlistsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredPlaylists, id: \.id) { playlist in
                    playlistRow(playlist)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func playlistRow(_ playlist: PlaylistEntity) -> some View {
        Group {
            PlaylistSelectRow(
                playlist: playlist,
                song: song,
                isAdded: playlist.songs.contains(where: { $0.id == song.id })
            )
            .contentShape(Rectangle())
            .onTapGesture {
                addToPlaylist(playlist)
            }

            if playlist.id != filteredPlaylists.last?.id {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 80)
            }
        }
    }

    private var closeButton: some View {
        Button("Cerrar") {
            dismiss()
        }
        .foregroundColor(.white)
    }

    private func addToPlaylist(_ playlist: PlaylistEntity) {
        Task {
            await viewModel.addSongToPlaylist(songID: song.id, playlistID: playlist.id)

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // Auto-dismiss after a short delay
            try? await Task.sleep(for: .milliseconds(300))
            dismiss()
        }
    }
}

//#Preview {
//    PreviewWrapper(
//        playlistVM: PreviewViewModels.playlistVM(),
//        modelContainer: PreviewData.container(with: PreviewSongs.generate())
//    ) {
//        AddToPlaylistView(song: PreviewSongs.single().toEntity())
//    }
//}
