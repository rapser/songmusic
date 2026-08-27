//
//  RankingWindowRepositoryImpl.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación de `RankingWindowRepositoryProtocol` sobre UserDefaults (JSON).
///
/// No toca SwiftData: el estado del ranking de Inicio es independiente del `playCount`
/// histórico de cada canción y no debe provocar migraciones del modelo persistente.
final class RankingWindowRepositoryImpl: RankingWindowRepositoryProtocol {

    /// Vida útil de la ventana: 7 días desde la primera reproducción del ciclo.
    static let windowDuration: TimeInterval = 7 * 24 * 60 * 60

    private struct Entry: Codable {
        var count: Int
        var startedAt: Date
    }

    private enum Keys {
        static let entries = "rankingWindowEntries"
    }

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    // MARK: - RankingWindowRepositoryProtocol

    func registerPlay(songID: UUID) {
        var entries = load()
        let current = now()

        if var entry = entries[songID.uuidString], !isExpired(entry, at: current) {
            entry.count += 1
            entries[songID.uuidString] = entry
        } else {
            entries[songID.uuidString] = Entry(count: 1, startedAt: current)
        }

        save(entries)
    }

    func activeCounts() -> [UUID: Int] {
        let current = now()
        let all = load()
        let alive = all.filter { !isExpired($0.value, at: current) }

        // Persistir la limpieza si alguna ventana caducó.
        if alive.count != all.count {
            save(alive)
        }

        return Dictionary(uniqueKeysWithValues: alive.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value.count) }
        })
    }

    func remove(songID: UUID) {
        var entries = load()
        guard entries.removeValue(forKey: songID.uuidString) != nil else { return }
        save(entries)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.entries)
    }

    // MARK: - Helpers

    private func isExpired(_ entry: Entry, at date: Date) -> Bool {
        date.timeIntervalSince(entry.startedAt) >= Self.windowDuration
    }

    private func load() -> [String: Entry] {
        guard let data = defaults.data(forKey: Keys.entries),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ entries: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.entries)
    }
}

// MARK: - Sendable Conformance

extension RankingWindowRepositoryImpl: @unchecked Sendable {}
