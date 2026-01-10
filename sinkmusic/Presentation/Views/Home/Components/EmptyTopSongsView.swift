//
//  EmptyTopSongsView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 23/12/25.
//


import SwiftUI

struct EmptyTopSongsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundColor(.textGray)

            Text("Aún no tienes historial")
                .font(.system(size: 14))
                .foregroundColor(.textGray)

            Text("Reproduce canciones para verlas aquí")
                .font(.system(size: 12))
                .foregroundColor(.textGray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}