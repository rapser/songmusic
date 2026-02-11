//
//  MetadataRepositoryImpl.swift
//  sinkmusic
//
//  Created by miguel tomairo
//  Clean Architecture - Data Layer
//

import Foundation

/// Implementación del repositorio de Metadata
/// Encapsula el MetadataService y proporciona extracción de metadata de audio
@MainActor
final class MetadataRepositoryImpl: MetadataRepositoryProtocol {

    // MARK: - Dependencies

    private let metadataService: MetadataService

    // MARK: - Initialization

    init(metadataService: MetadataService) {
        self.metadataService = metadataService
    }

    // MARK: - MetadataRepositoryProtocol

    func extractMetadata(from url: URL) async -> SongMetadata? {
        return await metadataService.extractMetadata(from: url)
    }
}

// MARK: - Sendable Conformance

extension MetadataRepositoryImpl: Sendable {}
