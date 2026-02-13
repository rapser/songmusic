//
//  PlaylistGridView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Refactored to Clean Architecture - Uses PlaylistUI

import SwiftUI

struct PlaylistGridView: View {
    let playlists: [PlaylistUI]
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
                    ForEach(playlists.prefix(4)) { playlist in
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
