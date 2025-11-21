//
//  PlaylistRepository.swift
//  sinkmusic
//
//  Created by Refactoring - Repository Pattern
//

import Foundation
import SwiftData

/// Repositorio concreto para gestionar playlists con SwiftData
/// Implementa Single Responsibility Principle: solo maneja el acceso a datos de playlists
final class PlaylistRepository: PlaylistRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll() throws -> [Playlist] {
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw AppError.data(.fetchFailed(error))
        }
    }
    
    func fetch(by id: UUID) throws -> Playlist? {
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw AppError.data(.fetchFailed(error))
        }
    }
    
    func save(_ playlist: Playlist) throws {
        modelContext.insert(playlist)
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.saveFailed(error))
        }
    }
    
    func update(_ playlist: Playlist) throws {
        playlist.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.saveFailed(error))
        }
    }
    
    func delete(_ playlist: Playlist) throws {
        modelContext.delete(playlist)
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.deleteFailed(error))
        }
    }
    
    func addSong(_ song: Song, to playlist: Playlist) throws {
        guard !playlist.songs.contains(where: { $0.id == song.id }) else {
            return // Canción ya existe en la playlist
        }
        
        playlist.songs.append(song)
        playlist.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.saveFailed(error))
        }
    }
    
    func removeSong(_ song: Song, from playlist: Playlist) throws {
        guard let index = playlist.songs.firstIndex(where: { $0.id == song.id }) else {
            return // Canción no está en la playlist
        }
        
        playlist.songs.remove(at: index)
        playlist.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            throw AppError.data(.deleteFailed(error))
        }
    }
}
