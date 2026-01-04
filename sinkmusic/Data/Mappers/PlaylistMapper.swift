//
//  PlaylistMapper.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Mapper para transformar entre las 3 capas: DTO ↔ Entity ↔ UIModel
enum PlaylistMapper {

    // MARK: - Layer 1: DTO → Entity (Data → Domain)

    /// Convierte DTO de SwiftData a Entidad de Dominio pura
    static func toEntity(_ dto: PlaylistDTO, songs: [SongEntity]) -> PlaylistEntity {
        let entity: PlaylistEntity = PlaylistEntity(
            id: dto.id,
            name: dto.name,
            description: dto.desc,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            coverImageData: dto.coverImageData,
            songs: songs
        )
        return entity
    }

    /// Convierte DTO con sus canciones a Entity (mapea canciones también)
    static func toEntityWithSongs(_ dto: PlaylistDTO) -> PlaylistEntity {
        let songEntities = dto.songs.map { SongMapper.toEntity($0) }
        return toEntity(dto, songs: songEntities)
    }

    /// Convierte array de DTOs a Entities
    static func toEntities(_ dtos: [PlaylistDTO]) -> [PlaylistEntity] {
        dtos.map { toEntityWithSongs($0) }
    }

    // MARK: - Layer 2: Entity → DTO (Domain → Data)

    /// Convierte Entidad de Dominio a DTO de SwiftData
    /// Nota: Las relaciones song-playlist se manejan por separado en el repositorio
    static func toDTO(_ entity: PlaylistEntity) -> PlaylistDTO {
        let dto: PlaylistDTO = PlaylistDTO(
            id: entity.id,
            name: entity.name,
            description: entity.description,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            coverImageData: entity.coverImageData,
            songs: [] // Las relaciones se manejan por separado
        )
        return dto
    }

    // MARK: - Layer 3: Entity → UIModel (Domain → Presentation)

    /// Convierte Entidad a Modelo de UI para las vistas
    static func toUIModel(_ entity: PlaylistEntity) -> PlaylistUIModel {
        PlaylistUIModel(
            id: entity.id,
            name: entity.name,
            description: entity.description,
            songCount: entity.songCount,
            formattedDuration: entity.formattedDuration,
            displayInfo: entity.displayInfo,
            coverImageData: entity.coverImageData,
            songs: entity.songs.map { SongMapper.toUIModel($0) },
            downloadProgress: entity.downloadProgress,
            isEmpty: entity.isEmpty
        )
    }

    /// Convierte array de Entities a UIModels
    static func toUIModels(_ entities: [PlaylistEntity]) -> [PlaylistUIModel] {
        entities.map { toUIModel($0) }
    }
}
