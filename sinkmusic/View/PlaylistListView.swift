//
//  PlaylistListView.swift
//  sinkmusic
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct PlaylistListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: PlaylistViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: PlaylistViewModel(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            Color.spotifyBlack.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Tu biblioteca")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { viewModel.showCreatePlaylist = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Playlists Grid
                if viewModel.playlists.isEmpty {
                    EmptyPlaylistsView {
                        viewModel.showCreatePlaylist = true
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
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist, modelContext: modelContext)) {
                                    PlaylistCardView(playlist: playlist)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreatePlaylist) {
            CreatePlaylistView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchPlaylists()
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            ZStack {
                if let coverData = playlist.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipped()
                } else {
                    // Default gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.6, brightness: 0.5),
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.7, brightness: 0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 160, height: 160)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(8)

            // Playlist Info
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(playlist.songCount) canciones")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.spotifyLightGray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty Playlists View
struct EmptyPlaylistsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.spotifyLightGray)

            VStack(spacing: 8) {
                Text("No tienes playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Crea tu primera playlist para empezar")
                    .font(.system(size: 14))
                    .foregroundColor(.spotifyLightGray)
            }

            Button(action: onCreate) {
                Text("Crear playlist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.spotifyGreen)
                    .cornerRadius(24)
            }
            .padding(.top, 10)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistListView(modelContext: PreviewContainer.shared.mainContext)
    }
}
