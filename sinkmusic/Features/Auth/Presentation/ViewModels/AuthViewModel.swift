//
//  AuthViewModel.swift
//  sinkmusic
//
//  Features/Auth - Presentation Layer ViewModel
//  Clean Architecture: ViewModel para autenticación
//

import Foundation
import AuthenticationServices

/// ViewModel para manejo de autenticación
/// Usa AuthUseCases y escucha eventos del EventBus
@MainActor
@Observable
final class AuthViewModel {

    // MARK: - Published State

    /// Estado actual de autenticación
    private(set) var authenticationState: AuthenticationState = .unknown

    /// Usuario está autenticado
    var isAuthenticated: Bool {
        authenticationState.isAuthenticated
    }

    /// Verificando estado de autenticación (mostrar loading)
    private(set) var isCheckingAuth: Bool = true

    /// Email del usuario autenticado
    var userEmail: String? {
        authenticationState.user?.email
    }

    /// Nombre completo del usuario autenticado
    var userFullName: String? {
        authenticationState.user?.fullName
    }

    /// ID del usuario autenticado
    var userID: String? {
        authenticationState.user?.id
    }

    /// UIModel del usuario para la vista (con datos formateados)
    var userUIModel: AuthUserUIModel? {
        AuthMapper.toUIModel(from: authenticationState)
    }

    // MARK: - Dependencies

    private let authUseCases: AuthUseCases
    private let eventBus: EventBusProtocol

    // MARK: - Tasks

    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(authUseCases: AuthUseCases, eventBus: EventBusProtocol) {
        self.authUseCases = authUseCases
        self.eventBus = eventBus
        startObservingEvents()
        syncInitialState()
    }

    // MARK: - Public Actions

    /// Iniciar Sign In with Apple
    func signIn() {
        authUseCases.signIn()
    }

    /// Procesar autorización exitosa de Apple
    func handleSuccessfulAuthorization(_ authorization: ASAuthorization) {
        authUseCases.handleAuthorization(authorization)
    }

    /// Cerrar sesión
    func signOut() {
        authUseCases.signOut()
    }

    /// Eliminar todos los datos de Apple
    func clearAllAppleData() {
        authUseCases.clearAllData()
    }

    // MARK: - Event Observation

    private func startObservingEvents() {
        observationTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.eventBus.authEvents() {
                guard !Task.isCancelled else { break }
                await self.handleAuthEvent(event)
            }
        }
    }

    private func handleAuthEvent(_ event: AuthEvent) async {
        switch event {
        case .signedIn(let userID, let email, let name):
            let user = AuthUserEntity(id: userID, email: email, fullName: name)
            authenticationState = .authenticated(user: user)
            isCheckingAuth = false

        case .signedOut:
            authenticationState = .unauthenticated

        case .checkCompleted(let authenticated):
            if !authenticated {
                authenticationState = .unauthenticated
            }
            isCheckingAuth = false
        }
    }

    // MARK: - Initial State Sync

    private func syncInitialState() {
        authenticationState = authUseCases.authenticationState
        isCheckingAuth = authUseCases.isCheckingAuth
    }

    // MARK: - Cleanup

    deinit {
        observationTask?.cancel()
    }
}

// MARK: - Sendable Conformance

extension AuthViewModel: @unchecked Sendable {}
