//
//  AccountSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - Account Section (Reusable Component)

struct AccountSectionView: View {
    let profile: UserProfileData

    var body: some View {
        VStack(spacing: 0) {
            if let email = profile.email {
                SettingsRowView(
                    icon: "envelope.fill",
                    title: "Correo electrónico",
                    value: email
                )
            } else {
                EmailNotSharedRowView()
            }

            if let userID = profile.userID {
                SettingsRowView(
                    icon: "person.text.rectangle.fill",
                    title: "ID de usuario",
                    value: String(userID.prefix(12))
                )
            }

            SettingsRowView(
                icon: "apple.logo",
                title: "Cuenta Apple",
                value: "Conectada"
            )
        }
    }
}

// MARK: - Email Not Shared Row

private struct EmailNotSharedRowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.textGray)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Correo electrónico")
                        .foregroundColor(.white)

                    Text("No compartido por Apple")
                        .font(.caption)
                        .foregroundColor(.textGray)
                }

                Spacer()
            }
            .padding(16)
            .background(Color.appGray)
        }
    }
}
