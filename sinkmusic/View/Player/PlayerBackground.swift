//
//  PlayerBackground.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Background del player con gradiente
struct PlayerBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            color.ignoresSafeArea(.all)

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
        }
    }
}
