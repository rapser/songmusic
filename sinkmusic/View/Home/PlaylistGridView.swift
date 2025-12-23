//
//  PlaylistGridView.swift
//  sinkmusic
//
//  Created by miguel tomairo

import SwiftUI
import SwiftData

struct PlaylistGridView: View {
    let playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreatePlaylist = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tus playlists")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            if playlists.isEmpty {
                EmptyPlaylistsView(onCreate: {
                    showCreatePlaylist = true
                })
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(playlists.prefix(8)) { playlist in
                        NavigationLink(destination: PlaylistDetailView(
                            playlist: playlist,
                            modelContext: modelContext
                        )) {
                            PlaylistGridCard(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
                .environment(\.modelContext, modelContext)
        }
    }
}

struct PlaylistGridCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
            ZStack {
                if let coverData = playlist.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.6, brightness: 0.5),
                            Color(hue: Double(playlist.name.hash % 100) / 100, saturation: 0.7, brightness: 0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(8)

            // Playlist name
            Text(playlist.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Song count
            Text("\(playlist.songCount) canciones")
                .font(.system(size: 12))
                .foregroundColor(.textGray)
        }
    }
}
