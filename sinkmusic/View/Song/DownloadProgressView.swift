//
//  DownloadProgressView.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import SwiftUI

/// Vista de progreso de descarga
struct DownloadProgressView: View {
    let progress: Double

    var body: some View {
        VStack {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .appPurple))
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(width: 100)
    }
}
