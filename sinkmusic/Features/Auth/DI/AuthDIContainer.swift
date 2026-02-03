//
//  AuthDIContainer.swift
//  sinkmusic
//
//  Features/Auth - Dependency Injection Container
//  Clean Architecture: Contenedor de DI aislado para Auth
//

import Foundation

/// Contenedor de Dependency Injection para el módulo Auth
/// Aislado del DIContainer principal para modularidad
@MainActor
final class AuthDIContainer {

    // MARK: - Dependencies

    private let eventBus: EventBusProtocol

    // MARK: - Initialization

    init(eventBus: EventBusProtocol) {
        self.eventBus = eventBus
    }

    // MARK: - DataSources

    private(set) lazy var localDataSource: AuthLocalDataSourceProtocol = AuthLocalDataSource()

    private(set) lazy var appleDataSource: AppleAuthDataSourceProtocol = AppleAuthDataSource()

    // MARK: - Repositories

    private(set) lazy var authRepository: AuthRepositoryProtocol = makeAuthRepository()

    private func makeAuthRepository() -> AuthRepositoryProtocol {
        AuthRepositoryImpl(
            localDataSource: localDataSource,
            appleDataSource: appleDataSource,
            eventBus: eventBus
        )
    }

    // MARK: - Use Cases

    private(set) lazy var authUseCases: AuthUseCases = AuthUseCases(authRepository: authRepository)

    // MARK: - ViewModel Factory

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authUseCases: authUseCases, eventBus: eventBus)
    }
}
