//
//  LoadingStateView.swift
//  sinkmusic
//
//  Estado de carga/sincronización
//

import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appPurple))
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Sincronizando...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Obteniendo canciones de Google Drive")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
