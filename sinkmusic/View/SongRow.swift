//
//  SongRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct SongRow: View {
    @Bindable var song: Song
    @EnvironmentObject var viewModel: MainViewModel // Keep MainViewModel for playerViewModel
    @EnvironmentObject var songListViewModel: SongListViewModel // New EnvironmentObject
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
            
            if let progress = songListViewModel.downloadProgress[song.id] { // Use songListViewModel
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
                Button(action: { viewModel.playerViewModel.play(song: song) }) { // Use viewModel.playerViewModel
                    Image(systemName: viewModel.playerViewModel.currentlyPlayingID == song.id && viewModel.playerViewModel.isPlaying // Use viewModel.playerViewModel
                          ? "pause.circle.fill"
                          : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.spotifyGreen)
                        .frame(width: 44, height: 44)
                }
            } else {
                Button(action: { songListViewModel.download(song: song, modelContext: modelContext) }) { // Use songListViewModel
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
    SongRowPreviewWrapper()
}

private struct SongRowPreviewWrapper: View {
    @State private var sampleSong = Song(
        id: UUID(),
        title: "Canción de Prueba",
        artist: "Artista",
        fileID: "file123",
        isDownloaded: false
    )

    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var songListViewModel = SongListViewModel()

    var body: some View {
        SongRow(song: sampleSong)
            .environmentObject(mainViewModel)
            .environmentObject(songListViewModel)
            .modelContainer(for: Song.self, inMemory: true)
            .padding()
            .background(Color.black)
    }
}
