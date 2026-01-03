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
    @Query(sort: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]) private var playlists: [Playlist]
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
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Playlists Grid
                if playlists.isEmpty {
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
                            ForEach(playlists, id: \.id) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist, modelContext: modelContext)) {
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
        .sheet(isPresented: $viewModel.showCreatePlaylist) {
            CreatePlaylistView()
                .environment(\.modelContext, modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistListView(modelContext: PreviewContainer.shared.mainContext)
    }
}
