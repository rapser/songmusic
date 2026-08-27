//
//  UserProfileSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - User Profile Section (Reusable Component)

/// Fila de perfil, plana (sin tarjeta), estilo cabecera de cuenta de Spotify/Tidal.
struct UserProfileSectionView: View {
    let profile: UserProfileData

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 52, height: 52)
                .foregroundColor(.appPurple)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.fullName ?? "Usuario Premium")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(profile.email ?? "Ver perfil")
                    .font(.subheadline)
                    .foregroundColor(.textGray)
            }

            Spacer()

            if profile.isAppleAccount {
                Image(systemName: "apple.logo")
                    .foregroundColor(.textGray)
            }
        }
        .padding(.vertical, 6)
    }
}
