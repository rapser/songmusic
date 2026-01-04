//
//  SearchResultRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//  Refactored to Clean Architecture - Uses SongUIModel
//

import SwiftUI

struct SearchResultRow: View, Equatable {
    let song: SongUIModel
    let currentlyPlayingID: UUID?
    let isPlaying: Bool
    let onTap: () -> Void

    // Implementar Equatable para optimizar re-renderizados
    static func == (lhs: SearchResultRow, rhs: SearchResultRow) -> Bool {
        lhs.song.id == rhs.song.id &&
        lhs.currentlyPlayingID == rhs.currentlyPlayingID &&
        lhs.isPlaying == rhs.isPlaying
    }

    private var cachedImage: UIImage? {
        if let thumbnailData = song.artworkThumbnail {
            return UIImage(data: thumbnailData)
        }
        return nil
    }

    private var isCurrentSongPlaying: Bool {
        currentlyPlayingID == song.id && isPlaying
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork - optimizado para evitar recreación constante
                ArtworkView(image: cachedImage)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrentSongPlaying ? .appPurple : .white)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.textGray)
                        .lineLimit(1)
                }

                Spacer()

                // Playing indicator
                if isCurrentSongPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(.appPurple)
                        .symbolEffect(.variableColor.iterative.reversing)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentlyPlayingID == song.id ? Color.appGray.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
