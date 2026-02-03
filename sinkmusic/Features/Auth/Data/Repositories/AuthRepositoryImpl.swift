//
//  AuthRepositoryImpl.swift
//  sinkmusic
//
//  Features/Auth - Data Layer Repository
//  Clean Architecture: Implementación del repositorio
//

import Foundation
import AuthenticationServices

/// Implementación del repositorio de autenticación
/// Coordina los DataSources y emite eventos al EventBus
@MainActor
final class AuthRepositoryImpl: AuthRepositoryProtocol {

    // MARK: - State

    private(set) var authenticationState: AuthenticationState = .unknown
    private(set) var isCheckingAuth: Bool = true

    var currentUser: AuthUserEntity? {
        authenticationState.user
    }

    // MARK: - Dependencies

    private let localDataSource: AuthLocalDataSourceProtocol
    private let appleDataSource: AppleAuthDataSourceProtocol
    private let eventBus: EventBusProtocol

    // MARK: - Initialization

    init(
        localDataSource: AuthLocalDataSourceProtocol,
        appleDataSource: AppleAuthDataSourceProtocol,
        eventBus: EventBusProtocol
    ) {
        self.localDataSource = localDataSource
        self.appleDataSource = appleDataSource
        self.eventBus = eventBus

        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Configurar callback de éxito
        var mutableAppleDataSource = appleDataSource
        mutableAppleDataSource.onAuthorizationSuccess = { [weak self] credential in
            Task { @MainActor [weak self] in
                self?.handleAuthorizationSuccess(credential)
            }
        }

        // Configurar callback de error
        mutableAppleDataSource.onAuthorizationFailure = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleAuthorizationFailure(error)
            }
        }
    }

    // MARK: - AuthRepositoryProtocol

    func signIn() {
        appleDataSource.startSignInFlow()
    }

    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ No se pudo obtener credencial de Apple")
            return
        }
        handleAuthorizationSuccess(credential)
    }

    func signOut() {
        localDataSource.clearUser()

        authenticationState = .unauthenticated
        isCheckingAuth = false

        eventBus.emit(.signedOut)
        print("🚪 Sesión cerrada")
    }

    func clearAllData() {
        localDataSource.clearUser()

        authenticationState = .unauthenticated
        isCheckingAuth = false

        eventBus.emit(.signedOut)
        print("🗑️ Todos los datos de autenticación eliminados")
    }

    func checkAuthenticationState() {
        isCheckingAuth = true
        authenticationState = .checking

        // Verificar si el usuario cerró sesión intencionalmente
        if localDataSource.didUserSignOut() {
            print("🚪 Usuario cerró sesión previamente")
            authenticationState = .unauthenticated
            isCheckingAuth = false
            eventBus.emit(.checkCompleted(isAuthenticated: false))
            return
        }

        // Verificar si hay un usuario guardado
        guard let savedUserID = localDataSource.getStoredUserID() else {
            print("ℹ️ No hay usuario guardado")
            authenticationState = .unauthenticated
            isCheckingAuth = false
            eventBus.emit(.checkCompleted(isAuthenticated: false))
            return
        }

        // Verificar credencial con Apple
        Task { @MainActor in
            let credentialState = await appleDataSource.verifyCredentialState(forUserID: savedUserID)

            switch credentialState {
            case .authorized:
                // Restaurar usuario
                let user = AuthMapper.toEntity(
                    id: savedUserID,
                    email: localDataSource.getStoredEmail(),
                    fullName: localDataSource.getStoredFullName()
                )
                authenticationState = .authenticated(user: user)
                isCheckingAuth = false
                print("✅ Sesión restaurada automáticamente")
                eventBus.emit(AuthMapper.toAuthEvent(user))

            case .revoked, .notFound:
                signOut()

            default:
                authenticationState = .unauthenticated
                isCheckingAuth = false
                eventBus.emit(.checkCompleted(isAuthenticated: false))
            }
        }
    }

    // MARK: - Private Handlers

    private func handleAuthorizationSuccess(_ credential: AppleCredentialProtocol) {
        print("📝 Autorización exitosa de Apple")

        // Crear entidad de usuario
        let user = AuthMapper.toEntity(
            from: credential,
            storedEmail: localDataSource.getStoredEmail(),
            storedName: localDataSource.getStoredFullName()
        )

        // Guardar en local
        localDataSource.saveUser(id: user.id, email: user.email, fullName: user.fullName)

        // Actualizar estado
        authenticationState = .authenticated(user: user)
        isCheckingAuth = false

        // Emitir evento
        eventBus.emit(AuthMapper.toAuthEvent(user))

        print("✅ Usuario autenticado: \(user.id)")
    }

    private func handleAuthorizationFailure(_ error: Error) {
        print("❌ Error de autenticación: \(error.localizedDescription)")
        isCheckingAuth = false
        eventBus.emit(.checkCompleted(isAuthenticated: false))
    }
}
