//
//  AuthRepositoryProtocol.swift
//  sinkmusic
//
//  Created by Clean Architecture Refactor
//  Domain Layer - Auth abstraction
//

import Foundation

/// Protocolo de repositorio para autenticación
/// Abstrae la implementación de Sign In with Apple
protocol AuthRepositoryProtocol: Sendable {
    /// Indica si el usuario está autenticado
    var isAuthenticated: Bool { get async }

    /// Indica si se está verificando el estado de autenticación
    var isCheckingAuth: Bool { get async }

    /// ID del usuario autenticado
    var userID: String? { get async }

    /// Email del usuario autenticado
    var userEmail: String? { get async }

    /// Nombre completo del usuario autenticado
    var userFullName: String? { get async }

    /// Inicia sesión con Apple
    func signIn() async throws

    /// Cierra la sesión actual
    func signOut() async

    /// Verifica el estado de autenticación al iniciar la app
    func checkAuthenticationState() async
}
