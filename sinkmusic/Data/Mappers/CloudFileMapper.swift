//
//  CloudFileMapper.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Mapper para convertir entre CloudFileDTO (Data Layer) y CloudFileEntity (Domain Layer)
enum CloudFileMapper {

    // MARK: - DTO → Entity

    /// Convierte CloudFileDTO a CloudFileEntity
    static func toEntity(from dto: CloudFileDTO) -> CloudFileEntity {
        CloudFileEntity(
            id: dto.id,
            name: dto.name,
            size: dto.size,
            mimeType: dto.mimeType,
            downloadURL: dto.downloadURL.flatMap { URL(string: $0) },
            provider: toEntityProvider(from: dto.provider)
        )
    }

    /// Convierte GoogleDriveFile a CloudFileEntity
    static func toEntity(from googleDriveFile: GoogleDriveFile) -> CloudFileEntity {
        CloudFileEntity(
            id: googleDriveFile.id,
            name: googleDriveFile.name,
            size: nil,
            mimeType: googleDriveFile.mimeType,
            downloadURL: nil,
            provider: .googleDrive
        )
    }

    /// Convierte array de GoogleDriveFile a array de CloudFileEntity
    static func toEntities(from googleDriveFiles: [GoogleDriveFile]) -> [CloudFileEntity] {
        googleDriveFiles.map { toEntity(from: $0) }
    }

    // MARK: - Entity → DTO

    /// Convierte CloudFileEntity a CloudFileDTO
    static func toDTO(from entity: CloudFileEntity) -> CloudFileDTO {
        CloudFileDTO(
            id: entity.id,
            name: entity.name,
            size: entity.size,
            mimeType: entity.mimeType,
            downloadURL: entity.downloadURL?.absoluteString,
            provider: toDTOProvider(from: entity.provider)
        )
    }

    // MARK: - Provider Mapping

    private static func toEntityProvider(from dtoProvider: CloudFileDTO.CloudProvider) -> CloudFileEntity.CloudProvider {
        switch dtoProvider {
        case .googleDrive: return .googleDrive
        case .oneDrive: return .oneDrive
        case .mega: return .mega
        case .dropbox: return .dropbox
        }
    }

    private static func toDTOProvider(from entityProvider: CloudFileEntity.CloudProvider) -> CloudFileDTO.CloudProvider {
        switch entityProvider {
        case .googleDrive: return .googleDrive
        case .oneDrive: return .oneDrive
        case .mega: return .mega
        case .dropbox: return .dropbox
        }
    }
}
