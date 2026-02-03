//
//  SongMapper.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation
import SwiftUI

/// Mapper para transformar entre las 3 capas: SongDTO ↔ Song ↔ SongUI
/// PATRÓN CRÍTICO que se replica en toda la app
enum SongMapper {

    // MARK: - Layer 1: DTO → Domain (Data → Domain)

    /// Convierte DTO de SwiftData a modelo de Dominio puro
    static func toDomain(_ dto: SongDTO) -> Song {
        Song(
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
            dominantColor: extractRGBColor(from: dto)
        )
    }

    /// Convierte array de DTOs a Domain
    static func toDomain(_ dtos: [SongDTO]) -> [Song] {
        dtos.map { toDomain($0) }
    }

    // MARK: - Layer 2: Domain → DTO (Domain → Data)

    /// Convierte modelo de Dominio a DTO de SwiftData
    static func toDTO(_ song: Song) -> SongDTO {
        let dto = SongDTO(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            author: song.author,
            fileID: song.fileID,
            isDownloaded: song.isDownloaded,
            duration: song.duration,
            artworkData: song.artworkData
        )

        // Propiedades adicionales que no están en el init
        dto.artworkThumbnail = song.artworkThumbnail
        dto.artworkMediumThumbnail = song.artworkMediumThumbnail
        dto.playCount = song.playCount
        dto.lastPlayedAt = song.lastPlayedAt

        // Almacenar dominant color como componentes RGB
        storeRGBColor(song.dominantColor, in: dto)

        return dto
    }

    // MARK: - Layer 3: Domain → UI (Domain → Presentation)

    /// Convierte modelo de Dominio a modelo de UI para las vistas
    static func toUI(_ song: Song) -> SongUI {
        SongUI(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album ?? "Álbum Desconocido",
            duration: song.formattedDuration,
            durationSeconds: song.duration ?? 0,
            artworkThumbnail: song.artworkMediumThumbnail,
            artworkSmallThumbnail: song.artworkThumbnail,
            isDownloaded: song.isDownloaded,
            playCount: song.playCount,
            playCountText: song.playCountText,
            dominantColor: toSwiftUIColor(song.dominantColor),
            artistAlbumInfo: song.artistAlbumInfo
        )
    }

    /// Convierte array de Domain a UI
    static func toUI(_ songs: [Song]) -> [SongUI] {
        songs.map { toUI($0) }
    }

    // MARK: - Helpers Privados

    /// Extrae RGBColor (Domain) de los componentes almacenados en DTO
    private static func extractRGBColor(from dto: SongDTO) -> RGBColor? {
        guard let r = dto.cachedDominantColorRed,
              let g = dto.cachedDominantColorGreen,
              let b = dto.cachedDominantColorBlue else {
            return nil
        }
        return RGBColor(red: r, green: g, blue: b)
    }

    /// Almacena RGBColor como componentes en DTO
    private static func storeRGBColor(_ color: RGBColor?, in dto: SongDTO) {
        guard let color = color else {
            dto.cachedDominantColorRed = nil
            dto.cachedDominantColorGreen = nil
            dto.cachedDominantColorBlue = nil
            return
        }

        dto.cachedDominantColorRed = color.red
        dto.cachedDominantColorGreen = color.green
        dto.cachedDominantColorBlue = color.blue
    }

    /// Convierte RGBColor (Domain) a SwiftUI.Color (Presentation)
    private static func toSwiftUIColor(_ rgbColor: RGBColor?) -> Color? {
        guard let rgb = rgbColor else { return nil }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
