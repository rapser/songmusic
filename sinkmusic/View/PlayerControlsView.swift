//
//  PlayerControlsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import SwiftUI

struct PlayerControlsView: View {
    let song: Song
    var namespace: Namespace.ID
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .resizable()
                .frame(width: 30, height: 30)
                .padding()
                .background(Color.spotifyGreen)
                .cornerRadius(8)
                

            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.spotifyLightGray)
            }
            Spacer()
            Button(action: { viewModel.play(song: song) }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .padding(.trailing)
        }
        .background(Color.spotifyGray)
        .cornerRadius(12)
        .padding(.horizontal)
        .matchedGeometryEffect(id: "player", in: namespace)
    }
}

#Preview {
    PlayerControlsViewPreviewWrapper()
}

private struct PlayerControlsViewPreviewWrapper: View {
    @Namespace private var namespace

    var body: some View {
        // Crear canción de ejemplo
        let exampleSong = Song(id: UUID(), title: "Song 1", artist: "Artist 1", fileID: "file1", isDownloaded: false)
        
        // Instancia de ViewModel de prueba
        let viewModel = MainViewModel()
        viewModel.isPlaying = true
        
        return PlayerControlsView(
            song: exampleSong,
            namespace: namespace
        )
        .environmentObject(viewModel)
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all)) // Fondo para que se vea bien en el preview
    }
}
