//
//  ErrorStateView.swift
//  sinkmusic
//
//  Estado de error de sincronización
//

import SwiftUI

struct ErrorStateView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Error de sincronización")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            NavigationLink(destination: GoogleDriveConfigView()) {
                Text("Revisar Configuración")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }
            .padding(.top, 10)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
