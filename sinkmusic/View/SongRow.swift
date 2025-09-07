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
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.spotifyLightGray)
            }
            Spacer()
            
            if let progress = viewModel.downloadProgress[song.id] {
                if progress < 0 {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 100)
                } else {
                    VStack {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .spotifyGreen))
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100)
                }
            } else if song.isDownloaded {
                Button(action: { viewModel.play(song: song) }) {
                    Image(systemName: viewModel.currentlyPlayingID == song.id && viewModel.isPlaying
                          ? "pause.circle.fill"
                          : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.spotifyGreen)
                        .frame(width: 44, height: 44)
                }
            } else {
                Button(action: { viewModel.download(song: song, modelContext: modelContext) }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.spotifyGreen)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.spotifyBlack)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let sampleSong = Song(title: "Canción de Prueba",
                          artist: "artista", fileID: "file123",
                          isDownloaded: false)

    let viewModel = MainViewModel()

    SongRow(song: sampleSong)
        .environmentObject(viewModel)
        .modelContainer(for: Song.self, inMemory: true)
        .padding()
}

