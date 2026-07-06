//
//  SearchUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class SearchUseCasesTests: XCTestCase {

    private var sut: SearchUseCases!
    private var mockSongRepo: MockSongRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        sut = SearchUseCases(songRepository: mockSongRepo)
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        super.tearDown()
    }

    // MARK: - searchSongs()

    func test_search_emptyQuery_returnsAllSongs() async throws {
        mockSongRepo.songs = [Song.make(title: "A"), Song.make(title: "B")]

        let result = try await sut.searchSongs(query: "")

        XCTAssertEqual(result.count, 2)
    }

    func test_search_matchesTitle_caseInsensitive() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Bohemian Rhapsody"),
            Song.make(title: "Hotel California")
        ]

        let result = try await sut.searchSongs(query: "bohemian")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Bohemian Rhapsody")
    }

    func test_search_matchesArtist() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Song A", artist: "Queen"),
            Song.make(title: "Song B", artist: "Eagles")
        ]

        let result = try await sut.searchSongs(query: "queen")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.artist, "Queen")
    }

    func test_search_matchesAlbum() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Track 1", album: "Abbey Road"),
            Song.make(title: "Track 2", album: "Dark Side")
        ]

        let result = try await sut.searchSongs(query: "abbey")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.album, "Abbey Road")
    }

    func test_search_noMatch_returnsEmpty() async throws {
        mockSongRepo.songs = [Song.make(title: "Hello World")]

        let result = try await sut.searchSongs(query: "xyz123")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - filterByArtist()

    func test_filterByArtist_exactMatch() async throws {
        mockSongRepo.songs = [
            Song.make(artist: "Queen"),
            Song.make(artist: "queen")  // case-sensitive, won't match
        ]

        let result = try await sut.filterByArtist("Queen")

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - filterByAlbum()

    func test_filterByAlbum_returnsMatchingAlbum() async throws {
        mockSongRepo.songs = [
            Song.make(album: "Abbey Road"),
            Song.make(album: "Let It Be")
        ]

        let result = try await sut.filterByAlbum("Abbey Road")

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - getDownloadedSongs() / getNotDownloadedSongs()

    func test_getDownloadedSongs_returnsOnlyDownloaded() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        let result = try await sut.getDownloadedSongs()

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first!.isDownloaded)
    }

    func test_getNotDownloadedSongs_returnsOnlyPending() async throws {
        mockSongRepo.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        let result = try await sut.getNotDownloadedSongs()

        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result.first!.isDownloaded)
    }

    // MARK: - getMostPlayedSongs()

    func test_getMostPlayedSongs_sortsByPlayCountDesc() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Low", playCount: 1),
            Song.make(title: "High", playCount: 99),
            Song.make(title: "Zero", playCount: 0)
        ]

        let result = try await sut.getMostPlayedSongs(limit: 2)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "High")
    }

    func test_getMostPlayedSongs_excludesUnplayed() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Played", playCount: 5),
            Song.make(title: "Never", playCount: 0)
        ]

        let result = try await sut.getMostPlayedSongs(limit: 10)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Played")
    }

    // MARK: - advancedSearch()

    func test_advancedSearch_combinedFilters() async throws {
        mockSongRepo.songs = [
            Song.make(title: "Song A", artist: "Queen", isDownloaded: true),
            Song.make(title: "Song B", artist: "Queen", isDownloaded: false),
            Song.make(title: "Song C", artist: "Eagles", isDownloaded: true)
        ]

        let result = try await sut.advancedSearch(
            query: nil,
            artist: "Queen",
            album: nil,
            downloadedOnly: true
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Song A")
    }

    // MARK: - sortSongs()

    func test_sortByTitle_alphabetically() {
        let songs = [Song.make(title: "Z"), Song.make(title: "A"), Song.make(title: "M")]

        let sorted = sut.sortSongs(songs, by: .title)

        XCTAssertEqual(sorted.map { $0.title }, ["A", "M", "Z"])
    }

    func test_sortByArtist_alphabetically() {
        let songs = [Song.make(artist: "Queen"), Song.make(artist: "ABBA"), Song.make(artist: "Eagles")]

        let sorted = sut.sortSongs(songs, by: .artist)

        XCTAssertEqual(sorted.map { $0.artist }, ["ABBA", "Eagles", "Queen"])
    }

    func test_sortByPlayCount_descending() {
        let songs = [Song.make(playCount: 3), Song.make(playCount: 10), Song.make(playCount: 1)]

        let sorted = sut.sortSongs(songs, by: .playCount)

        XCTAssertEqual(sorted.map { $0.playCount }, [10, 3, 1])
    }

    func test_sortByDuration_descending() {
        let songs = [Song.make(duration: 60), Song.make(duration: 300), Song.make(duration: 120)]

        let sorted = sut.sortSongs(songs, by: .duration)

        XCTAssertEqual(sorted.map { $0.duration }, [300, 120, 60])
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

    // MARK: - getRecentlyPlayedSongs()

    func test_getRecentlyPlayedSongs_sortsByDateDescending() async throws {
        let older = Song.make(title: "Old", lastPlayedAt: Date(timeIntervalSinceNow: -300))
        let newer = Song.make(title: "New", lastPlayedAt: Date(timeIntervalSinceNow: -10))
        let never = Song.make(title: "Never", lastPlayedAt: nil)
        mockSongRepo.songs = [older, newer, never]

        let result = try await sut.getRecentlyPlayedSongs(limit: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.title, "New")
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
