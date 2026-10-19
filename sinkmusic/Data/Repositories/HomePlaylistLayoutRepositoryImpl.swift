//
//  HomePlaylistLayoutRepositoryImpl.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de curaduría de playlists en Inicio usando UserDefaults.
/// El orden completo se guarda como un array de UUIDs (Inicio primero, luego Otros) junto
/// con el corte que separa ambos grupos.
final class HomePlaylistLayoutRepositoryImpl: HomePlaylistLayoutRepositoryProtocol {

    private enum Keys {
        static let order = "homePlaylistOrder"
        static let homeCount = "homePlaylistHomeCount"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (order: [UUID], homeCount: Int)? {
        guard let strings = defaults.array(forKey: Keys.order) as? [String] else {
            return nil
        }
        let order = strings.compactMap { UUID(uuidString: $0) }
        let homeCount = defaults.integer(forKey: Keys.homeCount)
        return (order, homeCount)
    }

    func save(order: [UUID], homeCount: Int) {
        defaults.set(order.map(\.uuidString), forKey: Keys.order)
        defaults.set(homeCount, forKey: Keys.homeCount)
    }
}

// MARK: - Sendable Conformance

// `@unchecked` por `UserDefaults`, que es thread-safe por documentación pero no está
// anotado `NS_SWIFT_SENDABLE` en Foundation, así que el compilador no puede verificarlo.
// El resto del tipo es inmutable.
extension HomePlaylistLayoutRepositoryImpl: @unchecked Sendable {}
