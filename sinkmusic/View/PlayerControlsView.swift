//
//  PlayerControlsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct PlayerControlsView: View {
    let song: Song
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .padding()
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { viewModel.play(song: song) }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .padding(.trailing)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    // Canción de ejemplo
    let sampleSong = Song(title: "Canción de Prueba", artist: "artista", fileID: "file123", isDownloaded: true)

    // ViewModel de prueba
    let viewModel = MainViewModel()

    PlayerControlsView(song: sampleSong)
        .environmentObject(viewModel)
        .modelContainer(for: Song.self, inMemory: true)
        .padding()
}
