//
//  PlaylistMapper.swift
//  sinkmusic
//
//  Created by miguel tomairo on 3/01/26.
//

import Foundation

/// Mapper para transformar entre las 3 capas: PlaylistDTO ↔ Playlist ↔ PlaylistUI
enum PlaylistMapper {

    // MARK: - Layer 1: DTO → Domain (Data → Domain)

    /// Convierte DTO de SwiftData a modelo de Dominio puro
    static func toDomain(_ dto: PlaylistDTO, songs: [Song]) -> Playlist {
        Playlist(
            id: dto.id,
            name: dto.name,
            description: dto.desc,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            coverImageData: dto.coverImageData,
            songs: songs
        )
    }

    /// Convierte DTO con sus canciones a Domain (mapea canciones también)
    static func toDomainWithSongs(_ dto: PlaylistDTO) -> Playlist {
        let songs = dto.songs.map { SongMapper.toDomain($0) }
        return toDomain(dto, songs: songs)
    }

    /// Convierte array de DTOs a Domain
    static func toDomain(_ dtos: [PlaylistDTO]) -> [Playlist] {
        dtos.map { toDomainWithSongs($0) }
    }

    // MARK: - Layer 2: Domain → DTO (Domain → Data)

    /// Convierte modelo de Dominio a DTO de SwiftData
    /// Nota: Las relaciones song-playlist se manejan por separado en el repositorio
    static func toDTO(_ playlist: Playlist) -> PlaylistDTO {
        PlaylistDTO(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt,
            coverImageData: playlist.coverImageData,
            songs: [] // Las relaciones se manejan por separado
        )
    }

    // MARK: - Layer 3: Domain → UI (Domain → Presentation)

    /// Convierte modelo de Dominio a modelo de UI para las vistas
    static func toUI(_ playlist: Playlist) -> PlaylistUI {
        PlaylistUI(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            songCount: playlist.songCount,
            formattedDuration: playlist.formattedDuration,
            displayInfo: playlist.displayInfo,
            coverImageData: playlist.coverImageData,
            songs: playlist.songs.map { SongMapper.toUI($0) },
            downloadProgress: playlist.downloadProgress,
            isEmpty: playlist.isEmpty
        )
    }

    /// Convierte array de Domain a UI
    static func toUI(_ playlists: [Playlist]) -> [PlaylistUI] {
        playlists.map { toUI($0) }
    }
}
