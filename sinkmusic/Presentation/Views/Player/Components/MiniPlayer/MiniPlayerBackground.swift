//
//  MiniPlayerBackground.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Background del miniplayer con color dominante
struct MiniPlayerBackground: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.2))
            )
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}
