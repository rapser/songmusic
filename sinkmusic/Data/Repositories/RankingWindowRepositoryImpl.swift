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

    /// Vida útil de la ventana: 7 días **desde la última reproducción**. Cada escucha la
    /// reinicia, así que una canción en rotación no cae del ranking mientras se siga oyendo.
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
            let entry = try dataSource.entry(for: songID)
            let isAlive = entry.map { !isExpired($0.windowStartedAt, at: current) } ?? false

            // La ventana se reancla en cada reproducción. Antes el ancla era la primera
            // escucha del ciclo, así que una canción que se oía a diario caía igual el día 8
            // y volvía a empezar en 1 — justo las favoritas eran las que desaparecían.
            try dataSource.upsert(
                songID: songID,
                count: isAlive ? (entry?.count ?? 0) + 1 : 1,
                windowStartedAt: current
            )

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

    /// `windowStartedAt` es el momento en que arrancó la ventana vigente, es decir, la
    /// última reproducción registrada.
    private func isExpired(_ windowStartedAt: Date, at date: Date) -> Bool {
        windowStartedAt < cutoff(from: date)
    }
}

// MARK: - Sendable Conformance

extension RankingWindowRepositoryImpl: Sendable {}
