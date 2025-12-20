//
//  MiniPlayerInfo.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Información de la canción en el miniplayer
struct MiniPlayerInfo: View {
    let title: String
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(artist)
                .font(.system(size: 12))
                .foregroundColor(.textGray)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .drawingGroup()
    }
}
