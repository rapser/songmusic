//
//  AuthRepositoryImpl.swift
//  sinkmusic
//
//  Created by Clean Architecture Refactor
//  Data Layer - Auth implementation
//

import Foundation

/// Implementación del repositorio de autenticación
/// Envuelve AuthenticationManager para cumplir con Clean Architecture
@MainActor
final class AuthRepositoryImpl: AuthRepositoryProtocol {

    // MARK: - Dependencies

    private let authManager: AuthenticationManager

    // MARK: - Initialization

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    // MARK: - AuthRepositoryProtocol

    var isAuthenticated: Bool {
        get async { authManager.isAuthenticated }
    }

    var isCheckingAuth: Bool {
        get async { authManager.isCheckingAuth }
    }

    var userID: String? {
        get async { authManager.userID }
    }

    var userEmail: String? {
        get async { authManager.userEmail }
    }

    var userFullName: String? {
        get async { authManager.userFullName }
    }

    func signIn() async throws {
        authManager.signInWithApple()
    }

    func signOut() async {
        authManager.signOut()
    }

    func checkAuthenticationState() async {
        authManager.checkAuthenticationState()
    }
}
