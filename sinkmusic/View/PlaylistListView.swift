//
//  PlaylistListView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
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
            Color.appDark.edgesIgnoringSafeArea(.all)

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
            CreatePlaylistView(onPlaylistCreated: {
                viewModel.fetchPlaylists()
            })
            .environment(\.modelContext, modelContext)
        }
        .onAppear {
            viewModel.fetchPlaylists()
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: Playlist
    @State private var cachedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            ZStack {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipped()
                } else if playlist.coverImageData != nil {
                    // Mostrar placeholder mientras carga
                    Color.appGray
                        .frame(width: 160, height: 160)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
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
            .task(id: playlist.id) {
                // Cargar imagen en background para no bloquear el audio
                if let coverData = playlist.coverImageData, cachedImage == nil {
                    await Task.detached(priority: .userInitiated) {
                        let image = UIImage(data: coverData)
                        await MainActor.run {
                            cachedImage = image
                        }
                    }.value
                }
            }

            // Playlist Info
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(playlist.songCount) canciones")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textGray)
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
                .foregroundColor(.textGray)

            VStack(spacing: 8) {
                Text("No tienes playlists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Crea tu primera playlist para empezar")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
            }

            Button(action: onCreate) {
                Text("Crear playlist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
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
