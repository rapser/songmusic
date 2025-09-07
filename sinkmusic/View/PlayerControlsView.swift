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
        HStack(spacing: 0) {
            Image(systemName: "music.note")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .background(Color.spotifyGreen)

            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                Text(song.artist)
                    .font(.caption)
            }
            .padding(.leading)

            Spacer()

            Button(action: { viewModel.play(song: song) }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .padding(.trailing)
        }
        .frame(height: 50)
        .background(Color(red: 50/255, green: 50/255, blue: 50/255).opacity(0.7))
        .foregroundColor(.white)
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
