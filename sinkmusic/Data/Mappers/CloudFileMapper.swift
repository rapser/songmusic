//
//  CloudFileMapper.swift
//  sinkmusic
//
//  Created by Claude Code
//  Clean Architecture - Data Layer
//

import Foundation

/// Mapper para convertir entre CloudFileDTO (Data Layer) y CloudFile (Domain Layer)
enum CloudFileMapper {

    // MARK: - DTO → Domain

    /// Convierte CloudFileDTO a CloudFile
    static func toDomain(from dto: CloudFileDTO) -> CloudFile {
        CloudFile(
            id: dto.id,
            name: dto.name,
            size: dto.size,
            mimeType: dto.mimeType,
            downloadURL: dto.downloadURL.flatMap { URL(string: $0) },
            provider: toDomainProvider(from: dto.provider)
        )
    }

    /// Convierte GoogleDriveFile a CloudFile
    static func toDomain(from googleDriveFile: GoogleDriveFile) -> CloudFile {
        CloudFile(
            id: googleDriveFile.id,
            name: googleDriveFile.name,
            size: nil,
            mimeType: googleDriveFile.mimeType,
            downloadURL: nil,
            provider: .googleDrive
        )
    }

    /// Convierte array de GoogleDriveFile a array de CloudFile
    static func toDomain(from googleDriveFiles: [GoogleDriveFile]) -> [CloudFile] {
        googleDriveFiles.map { toDomain(from: $0) }
    }

    // MARK: - Domain → DTO

    /// Convierte CloudFile a CloudFileDTO
    static func toDTO(from cloudFile: CloudFile) -> CloudFileDTO {
        CloudFileDTO(
            id: cloudFile.id,
            name: cloudFile.name,
            size: cloudFile.size,
            mimeType: cloudFile.mimeType,
            downloadURL: cloudFile.downloadURL?.absoluteString,
            provider: toDTOProvider(from: cloudFile.provider)
        )
    }

    // MARK: - Provider Mapping

    private static func toDomainProvider(from dtoProvider: CloudFileDTO.CloudProvider) -> CloudFile.CloudProvider {
        switch dtoProvider {
        case .googleDrive: return .googleDrive
        case .oneDrive: return .oneDrive
        case .mega: return .mega
        case .dropbox: return .dropbox
        }
    }

    private static func toDTOProvider(from domainProvider: CloudFile.CloudProvider) -> CloudFileDTO.CloudProvider {
        switch domainProvider {
        case .googleDrive: return .googleDrive
        case .oneDrive: return .oneDrive
        case .mega: return .mega
        case .dropbox: return .dropbox
        }
    }
}
