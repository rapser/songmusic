//
//  AuthFacade.swift
//  sinkmusic
//
//  Features/Auth - Facade Pattern
//  Oculta complejidad, expone API simple
//

import Foundation

/// Facade para autenticación
/// Coordina Strategy, Storage y EventBus
@MainActor
@Observable
final class AuthFacade {

    // MARK: - State

    /// Estado actual de autenticación
    private(set) var state: AuthState = .unknown

    /// Indica si está verificando autenticación
    private(set) var isCheckingAuth: Bool = true

    // MARK: - Dependencies

    private let strategy: AuthStrategy
    private let storage: UserDefaults
    private let eventBus: EventBusProtocol

    // MARK: - Storage Keys

    private enum Keys {
        static let user = "auth_user_v2"
        static let didSignOut = "auth_did_sign_out"
    }

    // MARK: - Init

    init(
        strategy: AuthStrategy,
        storage: UserDefaults = .standard,
        eventBus: EventBusProtocol
    ) {
        self.strategy = strategy
        self.storage = storage
        self.eventBus = eventBus
    }

    // MARK: - Public API

    /// Iniciar proceso de Sign In
    func signIn() async {
        do {
            let user = try await strategy.signIn()

            // Merge con datos existentes (Apple solo envía nombre/email la primera vez)
            let finalUser = mergeWithExistingUser(user)

            saveUser(finalUser)
            storage.set(false, forKey: Keys.didSignOut)
            state = .authenticated(finalUser)
            isCheckingAuth = false

            eventBus.emit(.signedIn(
                userID: finalUser.id,
                email: finalUser.email,
                name: finalUser.fullName
            ))

            print("✅ Auth: Sign in successful - \(finalUser.displayName)")

        } catch AuthError.cancelled {
            print("⚠️ Auth: Sign in cancelled by user")
            // No cambiar estado, usuario canceló

        } catch {
            print("❌ Auth: Sign in error - \(error.localizedDescription)")
            state = .unauthenticated
            isCheckingAuth = false
        }
    }

    /// Cerrar sesión
    func signOut() {
        clearUser()
        storage.set(true, forKey: Keys.didSignOut)
        state = .unauthenticated
        eventBus.emit(.signedOut)

        print("✅ Auth: Signed out")
    }

    /// Verificar estado de autenticación al iniciar la app
    func checkAuth() async {
        isCheckingAuth = true
        state = .checking

        // Usuario cerró sesión intencionalmente
        if storage.bool(forKey: Keys.didSignOut) {
            state = .unauthenticated
            isCheckingAuth = false
            eventBus.emit(.checkCompleted(isAuthenticated: false))
            print("ℹ️ Auth: User previously signed out")
            return
        }

        // Verificar usuario guardado
        guard let user = loadUser() else {
            state = .unauthenticated
            isCheckingAuth = false
            eventBus.emit(.checkCompleted(isAuthenticated: false))
            print("ℹ️ Auth: No saved user")
            return
        }

        // Verificar con el proveedor
        let isValid = await strategy.checkCredentialState(userID: user.id)

        if isValid {
            state = .authenticated(user)
            eventBus.emit(.signedIn(
                userID: user.id,
                email: user.email,
                name: user.fullName
            ))
            print("✅ Auth: Restored session for \(user.displayName)")
        } else {
            clearUser()
            state = .unauthenticated
            eventBus.emit(.checkCompleted(isAuthenticated: false))
            print("⚠️ Auth: Credentials revoked or expired")
        }

        isCheckingAuth = false
    }

    /// Limpiar todos los datos de autenticación
    func clearAllData() {
        clearUser()
        storage.removeObject(forKey: Keys.didSignOut)
        state = .unauthenticated
        eventBus.emit(.signedOut)

        print("✅ Auth: All data cleared")
    }

    // MARK: - Private Storage

    private func saveUser(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            storage.set(data, forKey: Keys.user)
        }
    }

    private func loadUser() -> AuthUser? {
        guard let data = storage.data(forKey: Keys.user) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    private func clearUser() {
        storage.removeObject(forKey: Keys.user)
    }

    /// Merge nuevo usuario con datos existentes
    /// Apple solo envía nombre/email la primera vez
    private func mergeWithExistingUser(_ newUser: AuthUser) -> AuthUser {
        guard let existingUser = loadUser(),
              existingUser.id == newUser.id else {
            return newUser
        }

        return AuthUser(
            id: newUser.id,
            email: newUser.email ?? existingUser.email,
            fullName: newUser.fullName ?? existingUser.fullName,
            provider: newUser.provider,
            createdAt: existingUser.createdAt
        )
    }
}

