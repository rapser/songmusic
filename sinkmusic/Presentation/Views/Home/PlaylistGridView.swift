//
//  PlaylistGridView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Refactored to Clean Architecture - Uses PlaylistUIModel

import SwiftUI

struct PlaylistGridView: View {
    let playlists: [PlaylistUIModel]
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
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            PlaylistGridCard(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
    }
}

struct PlaylistGridCard: View {
    let playlist: PlaylistUIModel

    var body: some View {
        HStack(spacing: 8) {
            // Cover image - 50x50
            ZStack {
                if let coverData = playlist.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
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
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
            }
            .cornerRadius(4)

            // Playlist name - centrado verticalmente
            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 50)
        .background(Color.white.opacity(0.1))
        .cornerRadius(4)
    }
}
