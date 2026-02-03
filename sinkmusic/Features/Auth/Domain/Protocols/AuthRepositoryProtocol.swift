//
//  AuthRepositoryProtocol.swift
//  sinkmusic
//
//  Features/Auth - Domain Layer Protocol
//  Clean Architecture: Abstracción del repositorio
//

import Foundation
import AuthenticationServices

/// Protocolo de repositorio para autenticación
/// Domain Layer - Define el contrato sin detalles de implementación
@MainActor
protocol AuthRepositoryProtocol: Sendable {

    // MARK: - State

    /// Estado actual de autenticación
    var authenticationState: AuthenticationState { get }

    /// Usuario actualmente autenticado (nil si no está autenticado)
    var currentUser: AuthUserEntity? { get }

    /// Indica si se está verificando el estado de autenticación
    var isCheckingAuth: Bool { get }

    // MARK: - Actions

    /// Inicia el flujo de Sign In with Apple
    func signIn()

    /// Procesa una autorización exitosa de Apple
    /// - Parameter authorization: Autorización de ASAuthorizationController
    func handleAuthorization(_ authorization: ASAuthorization)

    /// Cierra la sesión actual
    func signOut()

    /// Elimina todos los datos de autenticación guardados
    func clearAllData()

    /// Verifica el estado de autenticación al iniciar la app
    func checkAuthenticationState()
}
