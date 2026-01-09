//
//  AuthenticationServiceProtocol.swift
//  sinkmusic
//
//  Created by Claude Code - Clean Architecture
//  Infrastructure Layer - Service Protocol for Mocking
//

import Foundation
import AuthenticationServices

/// Protocolo para el servicio de autenticación con Sign In with Apple
/// Permite mockear AuthenticationManager para testing
@MainActor
protocol AuthenticationServiceProtocol: Sendable {

    // MARK: - Authentication State

    /// Estado de autenticación actual
    var isAuthenticated: Bool { get set }

    /// Estado de verificación de autenticación
    var isCheckingAuth: Bool { get set }

    /// ID del usuario autenticado
    var userID: String? { get set }

    /// Email del usuario autenticado
    var userEmail: String? { get set }

    /// Nombre completo del usuario autenticado
    var userFullName: String? { get set }

    // MARK: - Authentication Methods

    /// Verifica el estado de autenticación almacenado
    func checkAuthenticationState()

    /// Inicia el flujo de Sign In with Apple
    func signInWithApple()

    /// Procesa una autorización exitosa de Apple
    func handleSuccessfulAuthorization(_ authorization: ASAuthorization)

    /// Cierra la sesión actual
    func signOut()

    /// Elimina todos los datos de Apple guardados
    func clearAllAppleData()
}
