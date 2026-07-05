//
//  AllDownloadedView.swift
//  sinkmusic
//
//  Estado de todas las canciones descargadas
//

import SwiftUI

struct AllDownloadedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.appPurple)

            VStack(spacing: 8) {
                Text("Todo descargado")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Todas las canciones están descargadas")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
