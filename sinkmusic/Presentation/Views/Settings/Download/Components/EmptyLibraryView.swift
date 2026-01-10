//
//  EmptyLibraryView.swift
//  sinkmusic
//
//  Estado vacío de biblioteca
//

import SwiftUI

struct EmptyLibraryView: View {
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.appPurple)

            VStack(spacing: 8) {
                Text("Biblioteca vacía")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Sincroniza tus canciones desde Google Drive")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSync) {
                Text("Sincronizar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPurple)
                    .cornerRadius(24)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
