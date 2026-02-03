//
//  AppleAuthDataSource.swift
//  sinkmusic
//
//  Features/Auth - Data Layer DataSource
//  Clean Architecture: Interacción con Sign In with Apple
//

import Foundation
import AuthenticationServices
import UIKit

// MARK: - Apple Credential Protocol

/// Protocolo que abstrae las propiedades de ASAuthorizationAppleIDCredential
/// Permite usar credenciales reales y simuladas de forma intercambiable
protocol AppleCredentialProtocol: Sendable {
    var user: String { get }
    var email: String? { get }
    var fullName: PersonNameComponents? { get }
}

/// Extension para que ASAuthorizationAppleIDCredential conforme al protocolo
extension ASAuthorizationAppleIDCredential: AppleCredentialProtocol {}

// MARK: - DataSource Protocol

/// Protocolo para el DataSource de autenticación con Apple
@MainActor
protocol AppleAuthDataSourceProtocol: Sendable {
    /// Inicia el flujo de Sign In with Apple
    func startSignInFlow()

    /// Verifica el estado de la credencial con Apple
    func verifyCredentialState(forUserID userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState?

    /// Callback cuando la autenticación fue exitosa
    var onAuthorizationSuccess: ((AppleCredentialProtocol) -> Void)? { get set }

    /// Callback cuando la autenticación falló
    var onAuthorizationFailure: ((Error) -> Void)? { get set }
}

// MARK: - DataSource Implementation

/// DataSource para autenticación con Sign In with Apple
@MainActor
final class AppleAuthDataSource: NSObject, AppleAuthDataSourceProtocol, @unchecked Sendable {

    // MARK: - Callbacks

    var onAuthorizationSuccess: ((AppleCredentialProtocol) -> Void)?
    var onAuthorizationFailure: ((Error) -> Void)?

    // MARK: - Development Mode

    private let isDevelopmentMode: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    // MARK: - Sign In Flow

    func startSignInFlow() {
        // En modo desarrollo (simulador), simular autenticación exitosa
        if isDevelopmentMode {
            print("🔧 Modo Desarrollo: Simulando Sign In with Apple en simulador")

            let simulatedCredential = SimulatedAppleCredential(
                user: "dev_user_simulator",
                email: "dev@simulator.test",
                fullName: PersonNameComponents(givenName: "Usuario", familyName: "Simulador")
            )

            // Simular con un pequeño delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.onAuthorizationSuccess?(simulatedCredential)
            }
            return
        }

        // En dispositivo real, usar Sign In with Apple
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Credential Verification

    func verifyCredentialState(forUserID userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState? {
        // En modo desarrollo, siempre retornar authorized
        if isDevelopmentMode {
            return .authorized
        }

        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error = error {
                    print("❌ Error verificando credencial: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthDataSource: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        Task { @MainActor in
            onAuthorizationSuccess?(credential)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign In with Apple error: \(error.localizedDescription)")
        Task { @MainActor in
            onAuthorizationFailure?(error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthDataSource: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Acceder a la ventana principal de forma segura
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Simulated Credential for Development

/// Credencial simulada para desarrollo en simulador
/// Conforma a AppleCredentialProtocol en lugar de heredar de ASAuthorizationAppleIDCredential
struct SimulatedAppleCredential: AppleCredentialProtocol, Sendable {
    let user: String
    let email: String?
    let fullName: PersonNameComponents?

    init(user: String, email: String?, fullName: PersonNameComponents?) {
        self.user = user
        self.email = email
        self.fullName = fullName
    }
}
