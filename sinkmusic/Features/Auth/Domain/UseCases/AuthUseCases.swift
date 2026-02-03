//
//  AuthUseCases.swift
//  sinkmusic
//
//  Features/Auth - Domain Layer Use Cases
//  Clean Architecture: Casos de uso de autenticación
//

import Foundation
import AuthenticationServices

/// Casos de uso de autenticación
/// Encapsula la lógica de negocio de autenticación
@MainActor
final class AuthUseCases: Sendable {

    // MARK: - Dependencies

    private let authRepository: AuthRepositoryProtocol

    // MARK: - Initialization

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    // MARK: - Read State

    /// Obtiene el estado actual de autenticación
    var authenticationState: AuthenticationState {
        authRepository.authenticationState
    }

    /// Obtiene el usuario actual
    var currentUser: AuthUserEntity? {
        authRepository.currentUser
    }

    /// Indica si está verificando autenticación
    var isCheckingAuth: Bool {
        authRepository.isCheckingAuth
    }

    /// Indica si el usuario está autenticado
    var isAuthenticated: Bool {
        authRepository.authenticationState.isAuthenticated
    }

    // MARK: - Use Cases

    /// Inicia sesión con Apple
    func signIn() {
        authRepository.signIn()
    }

    /// Procesa autorización de Apple
    func handleAuthorization(_ authorization: ASAuthorization) {
        authRepository.handleAuthorization(authorization)
    }

    /// Cierra sesión
    func signOut() {
        authRepository.signOut()
    }

    /// Limpia todos los datos de autenticación
    func clearAllData() {
        authRepository.clearAllData()
    }

    /// Verifica estado de autenticación
    func checkAuthenticationState() {
        authRepository.checkAuthenticationState()
    }
}
