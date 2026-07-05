//
//  ReadStoreTestSupport.swift
//  sinkmusicTests
//

import Foundation
import SwiftData
@testable import sinkmusic

@MainActor
enum ReadStoreTestSupport {

    /// Crea un ModelContainer en memoria para tests de ReadStore reales.
    ///
    /// IMPORTANTE: el llamador debe quedarse con el `ModelContainer` devuelto (no solo con
    /// su `.mainContext`) durante toda la vida del test. `ModelContext` no retiene fuerte a
    /// su `ModelContainer` — si el container se libera (p.ej. por ser una variable local de
    /// una función auxiliar que ya retornó), el `ModelContext` queda apuntando a memoria
    /// inválida y cualquier operación posterior (`insert`/`save`) crashea con
    /// `EXC_BAD_INSTRUCTION` de forma impredecible. Este fue el causante real de los
    /// crashes reportados en esta suite — no un bug de SwiftData con `@Attribute(.unique)`.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SongDTO.self, PlaylistDTO.self, configurations: config)
    }

    static func makeSongLocalDataSource(_ context: ModelContext) -> SongLocalDataSource {
        SongLocalDataSource(modelContext: context)
    }

    static func makeSongRepository(_ context: ModelContext) -> SongRepositoryProtocol {
        SongRepositoryImpl(localDataSource: makeSongLocalDataSource(context))
    }

    static func makePlaylistRepository(_ context: ModelContext) -> PlaylistRepositoryProtocol {
        PlaylistRepositoryImpl(
            localDataSource: PlaylistLocalDataSource(modelContext: context),
            songRepository: makeSongRepository(context),
            songLocalDataSource: makeSongLocalDataSource(context)
        )
    }

    static func makeLibraryUseCases(_ context: ModelContext) -> LibraryUseCases {
        LibraryUseCases(
            songRepository: makeSongRepository(context),
            cloudStorageRepository: MockCloudStorageRepository(),
            credentialsRepository: MockCredentialsRepository()
        )
    }

    static func makePlaylistUseCases(_ context: ModelContext) -> PlaylistUseCases {
        PlaylistUseCases(
            playlistRepository: makePlaylistRepository(context),
            songRepository: makeSongRepository(context)
        )
    }

    static func makeSearchUseCases(_ context: ModelContext) -> SearchUseCases {
        SearchUseCases(songRepository: makeSongRepository(context))
    }

    @discardableResult
    static func insertSong(
        _ context: ModelContext,
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String? = nil,
        isDownloaded: Bool = false,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) throws -> SongDTO {
        let dto = SongDTO(
            title: title,
            artist: artist,
            album: album,
            fileID: UUID().uuidString,
            isDownloaded: isDownloaded
        )
        dto.playCount = playCount
        dto.lastPlayedAt = lastPlayedAt
        context.insert(dto)
        try context.save()
        return dto
    }

    @discardableResult
    static func insertPlaylist(
        _ context: ModelContext,
        name: String = "Test Playlist",
        songs: [SongDTO] = []
    ) throws -> PlaylistDTO {
        // Se crea vacía y se inserta primero — igual que PlaylistMapper.toDTO + addSong().
        // Asignar `songs` ya gestionadas por SwiftData dentro del init, antes de insertar
        // la playlist, hace crashear el runtime de SwiftData (relación a-muchos sin
        // contexto todavía). Por eso las canciones se agregan DESPUÉS del insert+save.
        let dto = PlaylistDTO(name: name)
        context.insert(dto)
        try context.save()

        if !songs.isEmpty {
            dto.songs = songs
            dto.songOrder = songs.map { $0.id.uuidString }.joined(separator: ",")
            try context.save()
        }

        return dto
    }
}
