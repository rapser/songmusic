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
    @State private var skeletonOpacity: Double = 0.4

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
                    playlistSkeletonGrid
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
            await viewModel.loadPlaylists()
        }
    }

    // MARK: - Skeleton

    private var playlistSkeletonGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 16
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    playlistSkeletonCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                skeletonOpacity = 0.15
            }
        }
    }

    private var playlistSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appGray)
                .frame(height: 160)
                .opacity(skeletonOpacity)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appGray)
                .frame(height: 13)
                .padding(.leading, 4)
                .padding(.trailing, 32)
                .opacity(skeletonOpacity)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appGray)
                .frame(height: 11)
                .padding(.leading, 4)
                .padding(.trailing, 56)
                .opacity(skeletonOpacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        PlaylistListView()
    }
}
