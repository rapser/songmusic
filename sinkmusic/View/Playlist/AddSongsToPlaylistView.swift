//
//  AddSongsToPlaylistView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 12/21/25.
//

import SwiftUI
import SwiftData

struct AddSongsToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PlaylistViewModel
    let playlist: Playlist

    // Query for all downloaded songs
    @Query private var allSongs: [Song]
    
    private var availableSongs: [Song] {
        let playlistSongIDs = Set(playlist.songs.map { $0.id })
        return allSongs.filter { $0.isDownloaded && !playlistSongIDs.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    if availableSongs.isEmpty {
                        Text("No hay más canciones para agregar.")
                            .foregroundColor(.textGray)
                            .padding()
                    } else {
                        List(availableSongs) { song in
                            AddSongRow(song: song) {
                                viewModel.addSong(song, to: playlist)
                            }
                            .listRowBackground(Color.appDark)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Agregar a esta playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct AddSongRow: View {
    let song: Song
    let onAdd: () -> Void
    
    @State private var wasAdded = false
    @State private var artworkImage: UIImage?

    var body: some View {
        HStack {
            Group {
                if let image = artworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.appGray
                        .overlay(Image(systemName: "music.note").foregroundColor(.textGray))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear(perform: loadImage)
            
            VStack(alignment: .leading) {
                Text(song.title).foregroundColor(.white).lineLimit(1)
                Text(song.artist).foregroundColor(.textGray).font(.caption).lineLimit(1)
            }
            
            Spacer()
            
            if wasAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appPurple)
                    .font(.title2)
            } else {
                Button(action: {
                    onAdd()
                    withAnimation {
                        wasAdded = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPurple)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func loadImage() {
        guard artworkImage == nil else { return }
        if let data = song.artworkThumbnail {
            self.artworkImage = UIImage(data: data)
        }
    }
}
