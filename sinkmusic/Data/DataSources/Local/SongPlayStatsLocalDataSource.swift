//
//  SongPlayStatsLocalDataSource.swift
//  sinkmusic
//
//  Clean Architecture - Data Layer
//

import Foundation
import SwiftData

/// Único escritor de `SongPlayStatsDTO`.
///
/// Sustituye a `SongDTO.playCount` / `SongDTO.lastPlayedAt` como fuente de verdad. Los
/// campos viejos siguen en el esquema (borrarlos exigiría un `AppSchemaV2`) y se usan solo
/// como semilla: la migración de datos es un **backfill perezoso en la primera lectura**,
/// que es el patrón que prescribe `CLAUDE.md`, no un `MigrationStage.custom`.
@MainActor
final class SongPlayStatsLocalDataSource {

    private let modelContext: ModelContext

    /// El backfill recorre las canciones con contador histórico, así que se hace una sola
    /// vez por ejecución y no en cada lectura: después de la primera pasada, este tipo es
    /// el único que escribe, así que no puede aparecer legacy nuevo.
    private var didRunBackfill = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Lectura

    /// Estadísticas de todas las canciones que tienen alguna, indexadas por `songID`.
    /// Una canción sin fila simplemente no aparece: equivale a `SongPlayStats.none`.
    func allStats() throws -> [UUID: SongPlayStats] {
        try runBackfillIfNeeded()

        let rows = try modelContext.fetch(FetchDescriptor<SongPlayStatsDTO>())
        return Dictionary(
            uniqueKeysWithValues: rows.map { ($0.songID, SongPlayStats(playCount: $0.playCount, lastPlayedAt: $0.lastPlayedAt)) }
        )
    }

    func stats(for songID: UUID) throws -> SongPlayStats? {
        try runBackfillIfNeeded()

        guard let row = try row(for: songID) else { return nil }
        return SongPlayStats(playCount: row.playCount, lastPlayedAt: row.lastPlayedAt)
    }

    /// IDs de las canciones escuchadas, de la más reciente a la más antigua.
    ///
    /// Sin `fetchLimit`: quien llama tiene que descartar después las que ya no están
    /// descargadas, y recortar antes dejaría huecos. La tabla tiene una fila por canción
    /// *escuchada*, no por canción de la biblioteca, así que es pequeña.
    func recentlyPlayedIDs() throws -> [UUID] {
        try runBackfillIfNeeded()

        let descriptor = FetchDescriptor<SongPlayStatsDTO>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\SongPlayStatsDTO.lastPlayedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.songID)
    }

    // MARK: - Escritura

    /// Suma una reproducción y marca la fecha. Es **la escritura caliente** de la app: toca
    /// solo esta entidad, así que únicamente despierta a quien vigile `SongPlayStatsDTO`.
    func increment(songID: UUID, at date: Date = Date()) throws {
        let row = try row(for: songID) ?? seededRow(for: songID)
        row.playCount += 1
        row.lastPlayedAt = date
        try modelContext.save()
    }

    /// Borra la fila de una canción. Se llama al borrar la canción, para no dejar
    /// estadísticas huérfanas.
    func delete(songID: UUID) throws {
        guard let row = try row(for: songID) else { return }
        modelContext.delete(row)
        try modelContext.save()
    }

    func deleteAll() throws {
        for row in try modelContext.fetch(FetchDescriptor<SongPlayStatsDTO>()) {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    // MARK: - Privado

    private func row(for songID: UUID) throws -> SongPlayStatsDTO? {
        let descriptor = FetchDescriptor<SongPlayStatsDTO>(
            predicate: #Predicate { $0.songID == songID }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Crea la fila de una canción que todavía no la tiene, **partiendo de los campos
    /// viejos de `SongDTO`**. Sin esta semilla, el primer play tras la migración dejaría el
    /// histórico en 1 y se perderían las reproducciones anteriores.
    private func seededRow(for songID: UUID) throws -> SongPlayStatsDTO {
        let legacy = try legacySong(songID)
        let row = SongPlayStatsDTO(
            songID: songID,
            playCount: legacy?.playCount ?? 0,
            lastPlayedAt: legacy?.lastPlayedAt
        )
        modelContext.insert(row)
        return row
    }

    private func legacySong(_ songID: UUID) throws -> SongDTO? {
        let descriptor = FetchDescriptor<SongDTO>(predicate: #Predicate { $0.id == songID })
        return try modelContext.fetch(descriptor).first
    }

    /// Crea las filas que falten para las canciones que ya traían contador histórico.
    /// Idempotente: una canción con fila nunca se vuelve a sembrar, así que no puede
    /// contar doble.
    private func runBackfillIfNeeded() throws {
        guard !didRunBackfill else { return }
        didRunBackfill = true

        let legacy = try modelContext.fetch(
            FetchDescriptor<SongDTO>(predicate: #Predicate { $0.playCount > 0 || $0.lastPlayedAt != nil })
        )
        guard !legacy.isEmpty else { return }

        let alreadyMigrated = Set(
            try modelContext.fetch(FetchDescriptor<SongPlayStatsDTO>()).map(\.songID)
        )

        var didInsert = false
        for song in legacy where !alreadyMigrated.contains(song.id) {
            modelContext.insert(
                SongPlayStatsDTO(songID: song.id, playCount: song.playCount, lastPlayedAt: song.lastPlayedAt)
            )
            didInsert = true
        }

        if didInsert {
            try modelContext.save()
        }
    }
}
