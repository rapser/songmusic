//
//  PlayerHeader.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Header del player con botones
struct PlayerHeader: View {
    @Binding var showEqualizer: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: { showEqualizer = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}
