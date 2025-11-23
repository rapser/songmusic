//
//  SongRepository.swift
//  sinkmusic
//
//  Created by Refactoring - Repository Pattern
//

import Foundation
import SwiftData

/// Repositorio concreto para gestionar canciones con SwiftData
/// Implementa Single Responsibility Principle: solo maneja el acceso a datos de canciones
final class SongRepository: SongRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll() throws -> [Song] {
        let descriptor = FetchDescriptor<Song>(sortBy: [SortDescriptor(\.title)])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw AppError.data(.fetchFailed(error))
        }
    }
    
    func fetch(by id: UUID) throws -> Song? {
        let descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw AppError.data(.fetchFailed(error))
        }
    }
    
    func fetchDownloaded() throws -> [Song] {
        let descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.isDownloaded == true },
            sortBy: [SortDescriptor(\.title)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw AppError.data(.fetchFailed(error))
        }
    }
    
    func save(_ song: Song) throws {
        modelContext.insert(song)
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.saveFailed(error))
        }
    }
    
    func update(_ song: Song) throws {
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.saveFailed(error))
        }
    }
    
    func delete(_ song: Song) throws {
        modelContext.delete(song)
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.deleteFailed(error))
        }
    }
}
