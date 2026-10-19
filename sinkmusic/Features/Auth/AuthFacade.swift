//
//  AuthFacade.swift
//  sinkmusic
//
//  Features/Auth - Facade Pattern
//  Oculta complejidad, expone API simple
//

import Foundation
import os

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

    // Nota: aquí había un `EventBusProtocol` para emitir `AuthEvent`. Nadie se suscribía
    // nunca: la reactividad de auth fluye por `state`, que es `@Observable`. Se quitaron
    // los seis emits, el stream y el tipo de evento.

    // MARK: - Storage Keys

    private enum Keys {
        static let user = "auth_user_v2"
        static let didSignOut = "auth_did_sign_out"
    }

    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "Auth")

    // MARK: - Init

    init(strategy: AuthStrategy, storage: UserDefaults = .standard) {
        self.strategy = strategy
        self.storage = storage
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

            logger.info("Auth: Sign in successful - \(finalUser.displayName)")

        } catch AuthError.cancelled {
            logger.info("Auth: Sign in cancelled by user")
            // No cambiar estado, usuario canceló

        } catch {
            logger.error("Auth: Sign in error - \(error.localizedDescription)")
            state = .unauthenticated
            isCheckingAuth = false
        }
    }

    /// Cerrar sesión
    func signOut() {
        clearUser()
        storage.set(true, forKey: Keys.didSignOut)
        state = .unauthenticated

        logger.info("Auth: Signed out")
    }

    /// Verificar estado de autenticación al iniciar la app
    func checkAuth() async {
        isCheckingAuth = true
        state = .checking

        // Usuario cerró sesión intencionalmente
        if storage.bool(forKey: Keys.didSignOut) {
            state = .unauthenticated
            isCheckingAuth = false
            logger.info("Auth: User previously signed out")
            return
        }

        // Verificar usuario guardado
        guard let user = loadUser() else {
            state = .unauthenticated
            isCheckingAuth = false
            logger.info("Auth: No saved user")
            return
        }

        // Verificar con el proveedor
        let isValid = await strategy.checkCredentialState(userID: user.id)

        if isValid {
            state = .authenticated(user)
            logger.info("Auth: Restored session for \(user.displayName)")
        } else {
            clearUser()
            state = .unauthenticated
            logger.warning("Auth: Credentials revoked or expired")
        }

        isCheckingAuth = false
    }

    /// Limpiar todos los datos de autenticación
    func clearAllData() {
        clearUser()
        storage.removeObject(forKey: Keys.didSignOut)
        state = .unauthenticated

        logger.info("Auth: All data cleared")
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

