//
//  LibraryAggregationUseCasesTests.swift
//  sinkmusicTests
//
//  Estaban en `SearchUseCasesTests`, pero agrupar la biblioteca por artista o álbum no es
//  buscar: lo consume el carrusel de Inicio y los selectores de filtro.
//

import XCTest
@testable import sinkmusic

@MainActor
final class LibraryAggregationUseCasesTests: XCTestCase {

    private var sut: LibraryAggregationUseCases!
    private var mockSongRepo: MockSongRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        sut = LibraryAggregationUseCases(songRepository: mockSongRepo)
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        super.tearDown()
    }

    // MARK: - getAllArtists() / getAllAlbums()

    func test_getAllArtists_returnsUniqueSorted() async throws {
        mockSongRepo.songs = [
            Song.make(artist: "Queen"),
            Song.make(artist: "ABBA"),
            Song.make(artist: "Queen")
        ]

        let result = try await sut.getAllArtists()

        XCTAssertEqual(result, ["ABBA", "Queen"])
    }

    func test_getAllAlbums_excludesNil() async throws {
        mockSongRepo.songs = [
            Song.make(album: "Abbey Road"),
            Song.make(album: nil),
            Song.make(album: "Let It Be")
        ]

        let result = try await sut.getAllAlbums()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result, ["Abbey Road", "Let It Be"])
    }

    // MARK: - getSongCountByAlbum()

    func test_getSongCountByAlbum_countsCorrectly() async throws {
        mockSongRepo.songs = [
            Song.make(album: "Abbey Road"),
            Song.make(album: "Abbey Road"),
            Song.make(album: "Let It Be"),
            Song.make(album: nil)
        ]

        let result = try await sut.getSongCountByAlbum()

        XCTAssertEqual(result["Abbey Road"], 2)
        XCTAssertEqual(result["Let It Be"], 1)
        XCTAssertNil(result[""]) // nil albums no se cuentan como clave vacía
    }

    // MARK: - getSongCountByArtist()

    func test_getSongCountByArtist_countsCorrectly() async throws {
        mockSongRepo.songs = [
            Song.make(artist: "Queen"),
            Song.make(artist: "Queen"),
            Song.make(artist: "Eagles")
        ]

        let result = try await sut.getSongCountByArtist()

        XCTAssertEqual(result["Queen"], 2)
        XCTAssertEqual(result["Eagles"], 1)
    }
}
