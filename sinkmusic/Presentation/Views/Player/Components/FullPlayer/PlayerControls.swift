//
//  PlayerControls.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Controles de reproducción (shuffle, prev, play, next, repeat)
struct PlayerControls: View {
    let isPlaying: Bool
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let onToggleShuffle: () -> Void
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onToggleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button(action: onToggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(isShuffleEnabled ? .appPurple : .textGray)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Previous
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Play/Pause
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
            }

            Spacer()

            // Next
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Repeat
            Button(action: onToggleRepeat) {
                Image(systemName: repeatMode == RepeatMode.repeatOne ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundColor(repeatMode != RepeatMode.off ? .appPurple : .textGray)
                    .frame(width: 50, height: 50)
            }
        }
        .padding(.horizontal, 20)
    }
}
