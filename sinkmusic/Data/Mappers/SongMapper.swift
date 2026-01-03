//
//  SongMapper.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Mapper para transformar entre las 3 capas: DTO ↔ Entity ↔ UIModel
/// PATRÓN CRÍTICO que se replica en toda la app
enum SongMapper {

    // MARK: - Layer 1: DTO → Entity (Data → Domain)

    /// Convierte DTO de SwiftData a Entidad de Dominio pura
    static func toEntity(_ dto: SongDTO) -> SongEntity {
        SongEntity(
            id: dto.id,
            title: dto.title,
            artist: dto.artist,
            album: dto.album,
            author: dto.author,
            fileID: dto.fileID,
            isDownloaded: dto.isDownloaded,
            duration: dto.duration,
            artworkData: dto.artworkData,
            artworkThumbnail: dto.artworkThumbnail,
            artworkMediumThumbnail: dto.artworkMediumThumbnail,
            playCount: dto.playCount,
            lastPlayedAt: dto.lastPlayedAt,
            dominantColor: extractDominantColor(from: dto)
        )
    }

    /// Convierte array de DTOs a Entities
    static func toEntities(_ dtos: [SongDTO]) -> [SongEntity] {
        dtos.map { toEntity($0) }
    }

    // MARK: - Layer 2: Entity → DTO (Domain → Data)

    /// Convierte Entidad de Dominio a DTO de SwiftData
    static func toDTO(_ entity: SongEntity) -> SongDTO {
        let dto = SongDTO(
            id: entity.id,
            title: entity.title,
            artist: entity.artist,
            album: entity.album,
            author: entity.author,
            fileID: entity.fileID,
            isDownloaded: entity.isDownloaded,
            duration: entity.duration,
            artworkData: entity.artworkData
        )

        // Propiedades adicionales que no están en el init
        dto.artworkThumbnail = entity.artworkThumbnail
        dto.artworkMediumThumbnail = entity.artworkMediumThumbnail
        dto.playCount = entity.playCount
        dto.lastPlayedAt = entity.lastPlayedAt

        // Almacenar dominant color como componentes RGB
        storeDominantColor(entity.dominantColor, in: dto)

        return dto
    }

    // MARK: - Layer 3: Entity → UIModel (Domain → Presentation)

    /// Convierte Entidad a Modelo de UI para las vistas
    static func toUIModel(_ entity: SongEntity) -> SongUIModel {
        SongUIModel(
            id: entity.id,
            title: entity.title,
            artist: entity.artist,
            album: entity.album ?? "Álbum Desconocido",
            duration: entity.formattedDuration,
            artworkThumbnail: entity.artworkMediumThumbnail,
            isDownloaded: entity.isDownloaded,
            playCount: entity.playCount,
            playCountText: entity.playCountText,
            dominantColor: entity.dominantColor,
            artistAlbumInfo: entity.artistAlbumInfo
        )
    }

    /// Convierte array de Entities a UIModels
    static func toUIModels(_ entities: [SongEntity]) -> [SongUIModel] {
        entities.map { toUIModel($0) }
    }

    // MARK: - Helpers Privados

    /// Extrae Color de los componentes RGB almacenados en DTO
    private static func extractDominantColor(from dto: SongDTO) -> Color? {
        guard let r = dto.cachedDominantColorRed,
              let g = dto.cachedDominantColorGreen,
              let b = dto.cachedDominantColorBlue else {
            return nil
        }
        return Color(red: r, green: g, blue: b)
    }

    /// Almacena Color como componentes RGB en DTO
    private static func storeDominantColor(_ color: Color?, in dto: SongDTO) {
        guard let color = color else {
            dto.cachedDominantColorRed = nil
            dto.cachedDominantColorGreen = nil
            dto.cachedDominantColorBlue = nil
            return
        }

        // Extraer componentes RGB de SwiftUI.Color
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        dto.cachedDominantColorRed = Double(red)
        dto.cachedDominantColorGreen = Double(green)
        dto.cachedDominantColorBlue = Double(blue)
        #endif
    }
}
