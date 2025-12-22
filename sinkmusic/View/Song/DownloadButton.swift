//
//  DownloadButton.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Botón de descarga
struct DownloadButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            print("DownloadButton tapped")
            action()
        }) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 24))
                .foregroundColor(.appPurple)
                .frame(width: 44, height: 44)
        }
        .contentShape(Rectangle())
    }
}
