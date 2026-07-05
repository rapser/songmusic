//
//  AllDownloadedView.swift
//  sinkmusic
//
//  Estado de todas las canciones descargadas
//

import SwiftUI

struct AllDownloadedView: View {
    let onSync: () -> Void

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

            Button(action: onSync) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Sincronizar carpeta")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appDark)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.appPurple)
                .cornerRadius(24)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
