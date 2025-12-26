//
//  UserProfileSectionView.swift
//  sinkmusic
//
//  Created by miguel tomairo
//

import SwiftUI

// MARK: - User Profile Section (Reusable Component)

struct UserProfileSectionView: View {
    let profile: UserProfileData

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.appPurple)

                VStack(alignment: .leading, spacing: 4) {
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
            .padding(16)
            .background(Color.appGray)
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}
