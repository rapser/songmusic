//
//  AuthViewModel.swift
//  sinkmusic
//
//  Features/Auth - ViewModel simplificado
//  Facade + Strategy Pattern
//

import Foundation

/// ViewModel para autenticación
/// Delega toda la lógica al AuthFacade
@MainActor
@Observable
final class AuthViewModel {

    // MARK: - Dependencies

    private let facade: AuthFacade

    // MARK: - Computed State (delegado a Facade)

    /// Estado actual de autenticación
    var state: AuthState { facade.state }

    /// Usuario está autenticado
    var isAuthenticated: Bool { state.isAuthenticated }

    /// Verificando estado de autenticación
    var isCheckingAuth: Bool { facade.isCheckingAuth }

    /// Usuario autenticado (si existe)
    var user: AuthUser? { state.user }

    // MARK: - Convenience para UI

    /// Email del usuario
    var userEmail: String? { user?.email }

    /// Nombre completo del usuario
    var userFullName: String? { user?.fullName }

    /// Nombre para mostrar
    var displayName: String { user?.displayName ?? "Usuario" }

    /// Email para mostrar
    var displayEmail: String { user?.displayEmail ?? "Email privado" }

    /// Iniciales del usuario
    var initials: String { user?.initials ?? "U" }

    /// Fecha de registro formateada
    var memberSinceFormatted: String { user?.memberSinceFormatted ?? "" }

    /// ID del usuario
    var userID: String? { user?.id }

    // MARK: - Init

    init(facade: AuthFacade) {
        self.facade = facade
    }

    // MARK: - Actions

    /// Iniciar sesión
    func signIn() {
        Task { await facade.signIn() }
    }

    /// Cerrar sesión
    func signOut() {
        facade.signOut()
    }

    /// Verificar autenticación al iniciar la app
    func checkAuth() {
        Task { await facade.checkAuth() }
    }

    /// Limpiar todos los datos de autenticación
    func clearAllData() {
        facade.clearAllData()
    }
}

