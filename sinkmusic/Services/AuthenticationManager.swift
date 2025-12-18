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
    @Published var isCheckingAuth: Bool = true  // Nuevo estado para evitar flash de login
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
            isCheckingAuth = false
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
                    self.isCheckingAuth = false
                }
            }
        } else {
            // No hay usuario guardado, finalizar verificación
            isCheckingAuth = false
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
        print("   Email: \(email ?? "nil (normal en login 2+)")")
        print("   FullName: \(fullName?.givenName ?? "nil") \(fullName?.familyName ?? "nil (normal en login 2+)")")

        // Guardar datos del usuario (solo si vienen datos nuevos)
        saveUserData(userID: userID, email: email, fullName: fullName)

        // Actualizar estado - priorizar datos nuevos, luego recuperar de UserDefaults
        self.userID = userID

        // Para email: usar el nuevo si existe, sino recuperar de UserDefaults
        if let email = email {
            self.userEmail = email
            print("✅ Email nuevo de Apple: \(email)")
        } else {
            self.userEmail = UserDefaults.standard.string(forKey: "appleUserEmail")
            if self.userEmail != nil {
                print("✅ Email recuperado de UserDefaults: \(self.userEmail!)")
            } else {
                print("⚠️ No hay email guardado")
            }
        }

        // Para nombre: construir si viene, sino recuperar de UserDefaults
        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            if !name.isEmpty {
                self.userFullName = name
                print("✅ Nombre nuevo de Apple: \(name)")
            } else {
                self.userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")
                if self.userFullName != nil {
                    print("✅ Nombre recuperado de UserDefaults: \(self.userFullName!)")
                } else {
                    print("⚠️ No hay nombre guardado")
                }
            }
        } else {
            self.userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")
            if self.userFullName != nil {
                print("✅ Nombre recuperado de UserDefaults: \(self.userFullName!)")
            } else {
                print("⚠️ No hay nombre guardado")
            }
        }

        print("📊 Estado final de autenticación:")
        print("   ✓ UserID: \(self.userID ?? "nil")")
        print("   ✓ Email: \(self.userEmail ?? "Sin email")")
        print("   ✓ Nombre: \(self.userFullName ?? "Sin nombre")")

        isAuthenticated = true
        isCheckingAuth = false
    }

    // MARK: - Sign Out

    /// Cierra la sesión actual pero mantiene email y nombre guardados
    /// para poder recuperarlos en el próximo login (Apple solo los envía la primera vez)
    func signOut() {
        isAuthenticated = false
        userID = nil
        userEmail = nil
        userFullName = nil

        // Solo borrar el userID para cerrar sesión
        // MANTENER email y nombre para poder recuperarlos en siguiente login
        UserDefaults.standard.removeObject(forKey: "appleUserID")

        print("🚪 Sesión cerrada. Email y nombre se mantienen para próximo login.")
    }

    /// Elimina TODOS los datos de Apple guardados (usar solo si el usuario quiere resetear todo)
    func clearAllAppleData() {
        isAuthenticated = false
        userID = nil
        userEmail = nil
        userFullName = nil

        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        UserDefaults.standard.removeObject(forKey: "appleUserFullName")

        print("🗑️ Todos los datos de Apple han sido eliminados.")
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
        isCheckingAuth = false
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign In with Apple error: \(error.localizedDescription)")
        isCheckingAuth = false
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
