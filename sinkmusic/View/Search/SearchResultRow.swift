//
//  SearchResultRow.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

struct SearchResultRow: View, Equatable {
    let song: Song
    let currentlyPlayingID: UUID?
    let isPlaying: Bool
    let onTap: () -> Void

    // Implementar Equatable para optimizar re-renderizados
    static func == (lhs: SearchResultRow, rhs: SearchResultRow) -> Bool {
        lhs.song.id == rhs.song.id &&
        lhs.currentlyPlayingID == rhs.currentlyPlayingID &&
        lhs.isPlaying == rhs.isPlaying
    }

    // Usar thumbnail medio optimizado para listas (100x100) en lugar del artwork completo
    private var cachedImage: UIImage? {
        // Preferir el thumbnail medio que es mucho más ligero (< 10KB vs cientos de KB)
        if let thumbnailData = song.artworkMediumThumbnail {
            return UIImage(data: thumbnailData)
        }
        // Fallback al artwork completo si no hay thumbnail (canciones viejas)
        if let artworkData = song.artworkData {
            return UIImage(data: artworkData)
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
