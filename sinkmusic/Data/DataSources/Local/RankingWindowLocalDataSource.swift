//
//  RankingWindowLocalDataSource.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// Acceso local (SwiftData) a las ventanas de ranking de Inicio.
/// Encapsula toda la interacción con `ModelContext` para `RankingWindowEntryDTO`.
@MainActor
final class RankingWindowLocalDataSource {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [RankingWindowEntryDTO] {
        try modelContext.fetch(FetchDescriptor<RankingWindowEntryDTO>())
    }

    func entry(for songID: UUID) throws -> RankingWindowEntryDTO? {
        let predicate = #Predicate<RankingWindowEntryDTO> { $0.songID == songID }
        var descriptor = FetchDescriptor<RankingWindowEntryDTO>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Inserta o actualiza la fila de una canción y persiste.
    func upsert(songID: UUID, count: Int, windowStartedAt: Date) throws {
        if let existing = try entry(for: songID) {
            existing.count = count
            existing.windowStartedAt = windowStartedAt
        } else {
            modelContext.insert(RankingWindowEntryDTO(songID: songID, count: count, windowStartedAt: windowStartedAt))
        }
        try modelContext.save()
    }

    /// Elimina las filas cuya ventana empezó antes de `cutoff` (ya caducadas). Persiste solo si borró algo.
    func deleteExpired(before cutoff: Date) throws {
        let expired = try modelContext.fetch(
            FetchDescriptor<RankingWindowEntryDTO>(predicate: #Predicate { $0.windowStartedAt < cutoff })
        )
        guard !expired.isEmpty else { return }
        for entry in expired { modelContext.delete(entry) }
        try modelContext.save()
    }

    func delete(songID: UUID) throws {
        guard let existing = try entry(for: songID) else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func deleteAll() throws {
        let all = try fetchAll()
        guard !all.isEmpty else { return }
        for entry in all { modelContext.delete(entry) }
        try modelContext.save()
    }
}
