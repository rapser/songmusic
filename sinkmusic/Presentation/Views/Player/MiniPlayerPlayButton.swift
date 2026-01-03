//
//  MiniPlayerPlayButton.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Botón de play/pause del miniplayer
struct MiniPlayerPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.appPurple)
                .cornerRadius(16)
        }
    }
}
