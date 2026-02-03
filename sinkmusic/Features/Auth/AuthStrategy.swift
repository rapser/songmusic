//
//  AuthStrategy.swift
//  sinkmusic
//
//  Features/Auth - Strategy Pattern para proveedores de autenticación
//  iOS 18+ APIs
//

import Foundation
import AuthenticationServices
import UIKit

// MARK: - Strategy Protocol

/// Protocolo para estrategias de autenticación
/// Cada proveedor (Apple, Google, Supabase) implementa este protocolo
@MainActor
protocol AuthStrategy: Sendable {
    /// Ejecuta el flujo de sign in y retorna el usuario
    func signIn() async throws -> AuthUser

    /// Verifica si las credenciales del usuario siguen válidas
    func checkCredentialState(userID: String) async -> Bool
}

// MARK: - Apple Strategy

/// Estrategia de autenticación con Sign In with Apple
@MainActor
final class AppleAuthStrategy: NSObject, AuthStrategy, @unchecked Sendable {

    private var continuation: CheckedContinuation<AuthUser, Error>?

    func signIn() async throws -> AuthUser {
        #if targetEnvironment(simulator)
        // Simulador: retornar usuario de prueba
        return AuthUser(
            id: "simulator_\(UUID().uuidString.prefix(8))",
            email: "test@simulator.local",
            fullName: "Usuario Simulador",
            provider: .apple,
            createdAt: Date()
        )
        #else
        // Dispositivo real: usar SignInWithAppleButton flow
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        #endif
    }

    func checkCredentialState(userID: String) async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
            return state == .authorized
        } catch {
            return false
        }
        #endif
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthStrategy: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor [weak self] in
                self?.continuation?.resume(throwing: AuthError.missingToken)
                self?.continuation = nil
            }
            return
        }

        let fullName: String? = {
            guard let components = credential.fullName else { return nil }
            let formatted = PersonNameComponentsFormatter.localizedString(
                from: components,
                style: .default,
                options: []
            )
            return formatted.isEmpty ? nil : formatted
        }()

        let user = AuthUser(
            id: credential.user,
            email: credential.email,
            fullName: fullName,
            provider: .apple,
            createdAt: Date()
        )

        Task { @MainActor [weak self] in
            self?.continuation?.resume(returning: user)
            self?.continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                self?.continuation?.resume(throwing: AuthError.cancelled)
            } else {
                self?.continuation?.resume(throwing: error)
            }
            self?.continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthStrategy: ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}

// ============================================================
// MARK: - Firebase/Google Strategy (Comentado - Futuro)
// ============================================================
//
// REQUISITOS:
// 1. SPM: firebase-ios-sdk, GoogleSignIn-iOS
// 2. GoogleService-Info.plist en el proyecto
// 3. URL Scheme: com.googleusercontent.apps.YOUR_CLIENT_ID (en Info.plist)
//
// NOTA iOS 18+: NO necesitas AppDelegate para callbacks.
// GoogleSignIn usa ASWebAuthenticationSession internamente.
//
// import FirebaseCore
// import FirebaseAuth
// import GoogleSignIn
//
// @MainActor
// final class FirebaseGoogleAuthStrategy: AuthStrategy {
//
//     func signIn() async throws -> AuthUser {
//         guard let clientID = FirebaseApp.app()?.options.clientID else {
//             throw AuthError.configurationMissing
//         }
//
//         GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
//
//         guard let windowScene = UIApplication.shared.connectedScenes
//             .compactMap({ $0 as? UIWindowScene })
//             .first(where: { $0.activationState == .foregroundActive }),
//               let rootVC = windowScene.windows.first?.rootViewController else {
//             throw AuthError.noRootViewController
//         }
//
//         let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
//
//         guard let idToken = result.user.idToken?.tokenString else {
//             throw AuthError.missingToken
//         }
//
//         let credential = GoogleAuthProvider.credential(
//             withIDToken: idToken,
//             accessToken: result.user.accessToken.tokenString
//         )
//
//         let authResult = try await Auth.auth().signIn(with: credential)
//
//         return AuthUser(
//             id: authResult.user.uid,
//             email: authResult.user.email,
//             fullName: authResult.user.displayName,
//             provider: .google,
//             createdAt: Date()
//         )
//     }
//
//     func checkCredentialState(userID: String) async -> Bool {
//         guard let currentUser = Auth.auth().currentUser else { return false }
//         do {
//             _ = try await currentUser.getIDToken()
//             return currentUser.uid == userID
//         } catch {
//             return false
//         }
//     }
// }

// ============================================================
// MARK: - Supabase Strategy (Comentado - Futuro)
// ============================================================
//
// REQUISITOS:
// 1. SPM: https://github.com/supabase/supabase-swift
// 2. Configurar en Supabase Dashboard: Authentication > Providers
//
// import Supabase
//
// @MainActor
// final class SupabaseAuthStrategy: AuthStrategy {
//
//     private let client: SupabaseClient
//
//     init(url: URL, key: String) {
//         self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
//     }
//
//     func signIn() async throws -> AuthUser {
//         try await client.auth.signInWithOAuth(provider: .google)
//         let session = try await client.auth.session
//
//         return AuthUser(
//             id: session.user.id.uuidString,
//             email: session.user.email,
//             fullName: session.user.userMetadata["full_name"]?.stringValue,
//             provider: .supabase,
//             createdAt: session.user.createdAt
//         )
//     }
//
//     func checkCredentialState(userID: String) async -> Bool {
//         do {
//             let session = try await client.auth.session
//             return session.user.id.uuidString == userID
//         } catch {
//             return false
//         }
//     }
// }

// ============================================================
// MARK: - REST API Strategy (Comentado - Futuro)
// ============================================================
//
// @MainActor
// final class RESTAPIAuthStrategy: AuthStrategy {
//
//     private let baseURL: URL
//     private let keychain: KeychainServiceProtocol
//
//     struct LoginResponse: Codable {
//         let userId: String
//         let email: String?
//         let fullName: String?
//         let accessToken: String
//         let refreshToken: String
//     }
//
//     init(baseURL: URL, keychain: KeychainServiceProtocol) {
//         self.baseURL = baseURL
//         self.keychain = keychain
//     }
//
//     func signIn() async throws -> AuthUser {
//         throw AuthError.credentialsRequired
//     }
//
//     func signIn(email: String, password: String) async throws -> AuthUser {
//         var request = URLRequest(url: baseURL.appendingPathComponent("/auth/login"))
//         request.httpMethod = "POST"
//         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//         request.httpBody = try JSONEncoder().encode(["email": email, "password": password])
//
//         let (data, response) = try await URLSession.shared.data(for: request)
//
//         guard let httpResponse = response as? HTTPURLResponse,
//               (200...299).contains(httpResponse.statusCode) else {
//             throw AuthError.invalidResponse
//         }
//
//         let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
//
//         try keychain.save(loginResponse.accessToken, for: "access_token")
//         try keychain.save(loginResponse.refreshToken, for: "refresh_token")
//
//         return AuthUser(
//             id: loginResponse.userId,
//             email: loginResponse.email,
//             fullName: loginResponse.fullName,
//             provider: .restAPI,
//             createdAt: Date()
//         )
//     }
//
//     func checkCredentialState(userID: String) async -> Bool {
//         guard let token = try? keychain.get("access_token") else { return false }
//
//         var request = URLRequest(url: baseURL.appendingPathComponent("/auth/me"))
//         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//         do {
//             let (_, response) = try await URLSession.shared.data(for: request)
//             guard let httpResponse = response as? HTTPURLResponse else { return false }
//             return httpResponse.statusCode == 200
//         } catch {
//             return false
//         }
//     }
// }
