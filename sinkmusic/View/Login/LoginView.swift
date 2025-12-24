//
//  LoginView.swift
//  sinkmusic
//
//  Login screen with Sign In with Apple
//  Spotify-style design
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authManager: AuthenticationManager

    var body: some View {
        ZStack {
            // Background gradient (Spotify style)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.appDark,
                    Color.appGray.opacity(0.8),
                    Color.appDark
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()

                // App Logo/Icon
                VStack(spacing: 24) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(.appPurple)
                        .shadow(color: .appPurple.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("App Music")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("Tu música local con calidad premium")
                        .font(.system(size: 16))
                        .foregroundColor(.textGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Features
                VStack(spacing: 20) {
                    FeatureBadge(
                        icon: "waveform.circle.fill",
                        title: "Calidad Premium",
                        description: "Procesamiento de audio profesional"
                    )

                    FeatureBadge(
                        icon: "arrow.down.circle.fill",
                        title: "Descarga tu música",
                        description: "Sincroniza desde Google Drive"
                    )

                    FeatureBadge(
                        icon: "list.bullet.rectangle.fill",
                        title: "Organiza tus playlists",
                        description: "Crea y gestiona tu biblioteca"
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                // Sign In with Apple Button
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            // Procesar directamente la autorización sin crear una segunda petición
                            authManager.handleSuccessfulAuthorization(authorization)
                        case .failure(let error):
                            print("Sign In error: \(error)")
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                    Text("Toca para iniciar sesión con Apple")
                        .font(.caption)
                        .foregroundColor(.textGray)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView(authManager: AuthenticationManager.shared)
}
