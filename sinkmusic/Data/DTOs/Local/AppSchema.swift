//
//  AppSchema.swift
//  sinkmusic
//
//  Esquema SwiftData versionado + plan de migración explícito.
//
//  Antes el `ModelContainer` se creaba sin `migrationPlan`, confiando en la migración
//  implícita — frágil con `@Attribute(.unique)` en `SongDTO` (ya rompió la app al añadir
//  campos y hubo que revertir). A partir de aquí, cada cambio de esquema = una nueva
//  `AppSchemaV#` + un `MigrationStage`.
//

import Foundation
import SwiftData

/// Esquema actual. `models` debe coincidir con el `for:` de todos los `ModelContainer(for:)`.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SongDTO.self, PlaylistDTO.self, RankingWindowEntryDTO.self, PlaylistItemDTO.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Sin etapas aún: solo hay una versión. Al introducir `AppSchemaV2` se añade
        // aquí `.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)`
        // (o `.custom(...)` si hay que transformar datos).
        []
    }
}

extension AppSchemaV1 {
    /// Azúcar para `ModelContainer(for: AppSchemaV1.schema, migrationPlan: AppMigrationPlan.self, ...)`.
    static var schema: Schema { Schema(models) }
}
