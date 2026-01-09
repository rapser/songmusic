//
//  AuthenticationManager.swift
//  sinkmusic
//
//  Sign In with Apple authentication manager
//

import Foundation
import AuthenticationServices

@MainActor
final class AuthenticationManager: NSObject, ObservableObject, AuthenticationServiceProtocol {
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
        // Debug: Verificar el estado de UserDefaults
        let didUserSignOut = UserDefaults.standard.bool(forKey: "didUserSignOut")
        let savedUserID = UserDefaults.standard.string(forKey: "appleUserID")

        print("🔍 Estado de autenticación:")
        print("   - didUserSignOut: \(didUserSignOut)")
        print("   - appleUserID guardado: \(savedUserID ?? "nil")")

        // Verificar si el usuario cerró sesión intencionalmente
        if didUserSignOut {
            // El usuario cerró sesión manualmente, mantener en LoginView
            print("🚪 Usuario cerró sesión previamente, mostrando LoginView")
            isCheckingAuth = false
            return
        }

        // Verificar si el usuario ya está autenticado
        if let savedUserID = savedUserID {
            userID = savedUserID
            userEmail = UserDefaults.standard.string(forKey: "appleUserEmail")
            userFullName = UserDefaults.standard.string(forKey: "appleUserFullName")

            // En modo desarrollo (simulador), confiar directamente en los datos guardados
            if isDevelopmentMode {
                self.isAuthenticated = true
                self.isCheckingAuth = false
                print("✅ Sesión restaurada automáticamente (modo desarrollo)")
                return
            }

            // En dispositivo real, verificar el estado de la credencial con Apple
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: savedUserID) { state, error in
                Task { @MainActor in
                    switch state {
                    case .authorized:
                        self.isAuthenticated = true
                        print("✅ Sesión restaurada automáticamente")
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
            print("ℹ️ No hay usuario guardado, mostrando LoginView")
            isCheckingAuth = false
        }
    }

    // MARK: - Sign In

    func signInWithApple() {
        // En modo desarrollo (simulador), simular autenticación exitosa
        if isDevelopmentMode {
            print("🔧 Modo Desarrollo: Simulando Sign In with Apple en simulador")

            // Simular credenciales de Apple
            let simulatedUserID = "dev_user_simulator"
            let simulatedEmail = "dev@simulator.test"
            let simulatedName = "Usuario Simulador"

            // Guardar en UserDefaults como si fuera un login real
            UserDefaults.standard.set(simulatedUserID, forKey: "appleUserID")
            UserDefaults.standard.set(simulatedEmail, forKey: "appleUserEmail")
            UserDefaults.standard.set(simulatedName, forKey: "appleUserFullName")

            // Limpiar el flag de cierre de sesión (usuario se está logueando)
            UserDefaults.standard.set(false, forKey: "didUserSignOut")

            // Forzar sincronización inmediata de UserDefaults
            UserDefaults.standard.synchronize()

            // Actualizar estado
            self.userID = simulatedUserID
            self.userEmail = simulatedEmail
            self.userFullName = simulatedName
            self.isAuthenticated = true
            self.isCheckingAuth = false

            print("✅ Login simulado exitoso")
            print("🔍 Estado después de login:")
            print("   - didUserSignOut guardado: \(UserDefaults.standard.bool(forKey: "didUserSignOut"))")
            print("   - appleUserID guardado: \(UserDefaults.standard.string(forKey: "appleUserID") ?? "nil")")
            return
        }

        // En dispositivo real, usar Sign In with Apple normal
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

        // Limpiar el flag de cierre de sesión (usuario se está logueando)
        UserDefaults.standard.set(false, forKey: "didUserSignOut")

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

        // Marcar que el usuario cerró sesión intencionalmente
        // Esto evita el auto-login al volver a abrir el app
        UserDefaults.standard.set(true, forKey: "didUserSignOut")

        // Forzar sincronización inmediata de UserDefaults
        UserDefaults.standard.synchronize()

        print("🚪 Sesión cerrada. Email y nombre se mantienen para próximo login.")
        print("🔍 Estado después de signOut:")
        print("   - didUserSignOut guardado: \(UserDefaults.standard.bool(forKey: "didUserSignOut"))")
        print("   - appleUserID guardado: \(UserDefaults.standard.string(forKey: "appleUserID") ?? "nil")")
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
        UserDefaults.standard.set(true, forKey: "didUserSignOut")

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

        // Limpiar el flag de cierre de sesión (usuario se está logueando)
        UserDefaults.standard.set(false, forKey: "didUserSignOut")

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
