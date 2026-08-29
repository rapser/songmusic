//
//  RankingWindowRepositoryImpl.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación de `RankingWindowRepositoryProtocol` sobre SwiftData
/// (`RankingWindowEntryDTO` vía `RankingWindowLocalDataSource`).
@MainActor
final class RankingWindowRepositoryImpl: RankingWindowRepositoryProtocol {

    /// Vida útil de la ventana: 7 días desde la primera reproducción del ciclo.
    static let windowDuration: TimeInterval = 7 * 24 * 60 * 60

    private let dataSource: RankingWindowLocalDataSource
    private let now: () -> Date

    init(dataSource: RankingWindowLocalDataSource, now: @escaping () -> Date = Date.init) {
        self.dataSource = dataSource
        self.now = now
    }

    // MARK: - RankingWindowRepositoryProtocol

    func registerPlay(songID: UUID) async {
        let current = now()
        do {
            if let entry = try dataSource.entry(for: songID), !isExpired(entry.windowStartedAt, at: current) {
                try dataSource.upsert(songID: songID, count: entry.count + 1, windowStartedAt: entry.windowStartedAt)
            } else {
                try dataSource.upsert(songID: songID, count: 1, windowStartedAt: current)
            }
            // Limpieza oportunista: aprovechamos esta escritura para purgar ventanas caducadas.
            try dataSource.deleteExpired(before: cutoff(from: current))
        } catch {
            // El ranking es accesorio: si falla la persistencia no debe romper la reproducción.
        }
    }

    func activeCounts() async -> [UUID: Int] {
        let limit = cutoff(from: now())
        let entries = (try? dataSource.fetchAll()) ?? []
        return Dictionary(uniqueKeysWithValues:
            entries
                .filter { $0.windowStartedAt >= limit }
                .map { ($0.songID, $0.count) }
        )
    }

    func remove(songID: UUID) async {
        try? dataSource.delete(songID: songID)
    }

    func clear() async {
        try? dataSource.deleteAll()
    }

    // MARK: - Helpers

    private func cutoff(from date: Date) -> Date {
        date.addingTimeInterval(-Self.windowDuration)
    }

    private func isExpired(_ windowStartedAt: Date, at date: Date) -> Bool {
        windowStartedAt < cutoff(from: date)
    }
}

// MARK: - Sendable Conformance

extension RankingWindowRepositoryImpl: Sendable {}
