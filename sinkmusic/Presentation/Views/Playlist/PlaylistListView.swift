//
//  PlaylistListView.swift
//  sinkmusic
//
//  Refactorizado con Clean Architecture
//  No SwiftData dependency
//

import SwiftUI

struct PlaylistListView: View {
    // MARK: - ViewModels (Clean Architecture)
    @Environment(PlaylistViewModel.self) private var viewModel
    @Environment(PlayerViewModel.self) private var playerViewModel

    @State private var showCreatePlaylist = false

    var body: some View {
        ZStack {
            Color.appDark.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Tu biblioteca")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showCreatePlaylist = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Loading State
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                }
                // Playlists Grid
                else if viewModel.playlists.isEmpty {
                    EmptyPlaylistsView {
                        showCreatePlaylist = true
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 16
                        ) {
                            ForEach(viewModel.playlists, id: \.id) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    PlaylistCardView(playlist: playlist)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
        .task {
            // Cargar playlists al aparecer
            await viewModel.loadPlaylists()
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistListView()
    }
}
