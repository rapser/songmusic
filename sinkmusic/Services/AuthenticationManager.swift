//
//  AuthenticationManager.swift
//  sinkmusic
//
//  Sign In with Apple authentication manager
//

import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var userID: String?
    @Published var userEmail: String?
    @Published var userFullName: String?

    static let shared = AuthenticationManager()

    // MARK: - Development Mode
    // Set to true to bypass Sign In with Apple in simulator
    private let isDevelopmentMode: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    private override init() {
        super.init()
        checkAuthenticationState()
    }

    // MARK: - Authentication State

    func checkAuthenticationState() {
        // En modo desarrollo (simulador), autenticar automáticamente
        if isDevelopmentMode {
            print("🔧 Modo Desarrollo: Auto-autenticación en simulador")
            userID = "dev_user_simulator"
            userEmail = "dev@simulator.test"
            userFullName = "Usuario Simulador"
            isAuthenticated = true
            return
        }

        // Verificar si el usuario ya está autenticado
        if let savedUserID = UserDefaults.standard.string(forKey: "appleUserID") {
            userID = savedUserID
            userEmail = UserDefaults.standard.string(forKey: "appleUserEmail")
            userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")

            // Verificar el estado de la credencial con Apple
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: savedUserID) { state, error in
                Task { @MainActor in
                    switch state {
                    case .authorized:
                        self.isAuthenticated = true
                    case .revoked, .notFound:
                        self.signOut()
                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Sign In

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // Procesar directamente una autorización exitosa (usado por SignInWithAppleButton)
    // IMPORTANTE: Apple solo proporciona email y nombre la PRIMERA vez que el usuario autoriza la app.
    // En logins subsiguientes, estos valores serán nil. Por eso los guardamos en UserDefaults.
    // Si el usuario revoca y vuelve a autorizar, Apple volverá a proporcionar los datos.
    func handleSuccessfulAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ No se pudo obtener credencial de Apple")
            return
        }

        let userID = credential.user
        let email = credential.email
        let fullName = credential.fullName

        print("📝 Datos recibidos de Apple:")
        print("   UserID: \(userID)")
        print("   Email: \(email ?? "nil")")
        print("   FullName: \(fullName?.givenName ?? "nil") \(fullName?.familyName ?? "nil")")

        // Guardar datos del usuario (solo si vienen datos nuevos)
        saveUserData(userID: userID, email: email, fullName: fullName)

        // Actualizar estado - priorizar datos nuevos, luego recuperar de UserDefaults
        self.userID = userID

        // Para email: usar el nuevo si existe, sino recuperar de UserDefaults
        if let email = email {
            self.userEmail = email
            print("✅ Email actualizado: \(email)")
        } else {
            self.userEmail = UserDefaults.standard.string(forKey: "appleUserEmail")
            print("ℹ️ Email recuperado de UserDefaults: \(self.userEmail ?? "nil")")
        }

        // Para nombre: construir si viene, sino recuperar de UserDefaults
        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            if !name.isEmpty {
                self.userFullName = name
                print("✅ Nombre actualizado: \(name)")
            } else {
                self.userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")
                print("ℹ️ Nombre recuperado de UserDefaults: \(self.userFullName ?? "nil")")
            }
        } else {
            self.userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")
            print("ℹ️ Nombre recuperado de UserDefaults: \(self.userFullName ?? "nil")")
        }

        print("📊 Estado final:")
        print("   UserID: \(self.userID ?? "nil")")
        print("   Email: \(self.userEmail ?? "nil")")
        print("   FullName: \(self.userFullName ?? "nil")")

        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() {
        isAuthenticated = false
        userID = nil
        userEmail = nil
        userFullName = nil

        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        UserDefaults.standard.removeObject(forKey: "appleUserFullName")
    }

    // MARK: - Private Helpers

    private func saveUserData(userID: String, email: String?, fullName: PersonNameComponents?) {
        UserDefaults.standard.set(userID, forKey: "appleUserID")

        if let email = email {
            UserDefaults.standard.set(email, forKey: "appleUserEmail")
        }

        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            if !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "appleUserFullName")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let userID = credential.user
        let email = credential.email
        let fullName = credential.fullName

        // Guardar datos del usuario
        saveUserData(userID: userID, email: email, fullName: fullName)

        // Actualizar estado
        self.userID = userID
        self.userEmail = email ?? UserDefaults.standard.string(forKey: "appleUserEmail")

        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            if !name.isEmpty {
                self.userFullName = name
            }
        } else {
            self.userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")
        }

        isAuthenticated = true
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign In with Apple error: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
