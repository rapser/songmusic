//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    @Bindable var song: Song
    @EnvironmentObject var viewModel: MainViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text("Artista Desconocido")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if let progress = viewModel.downloadProgress[song.id] {
                if progress < 0 {
                    ProgressView()
                        .frame(width: 100)
                } else {
                    VStack {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                    }
                    .frame(width: 100)
                }
            } else if song.isDownloaded {
                Button(action: { viewModel.play(song: song) }) {
                    Image(systemName: viewModel.currentlyPlayingID == song.id && viewModel.isPlaying
                          ? "pause.fill"
                          : "play.fill")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                }
            } else {
                Button(action: { viewModel.download(song: song, modelContext: modelContext) }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    // Canción de ejemplo
    let sampleSong = Song(title: "Canción de Prueba",
                          fileID: "file123",
                          isDownloaded: false)

    // ViewModel de prueba
    let viewModel = MainViewModel()

    SongRow(song: sampleSong)
        .environmentObject(viewModel)
        .modelContainer(for: Song.self, inMemory: true)
        .padding()
}

