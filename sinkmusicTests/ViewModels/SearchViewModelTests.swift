//
//  SearchViewModelTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class SearchViewModelTests: XCTestCase {

    private var sut: SearchViewModel!
    private var mockReadStore: MockSearchReadStore!

    override func setUp() {
        super.setUp()
        mockReadStore = MockSearchReadStore()
        sut = SearchViewModel(readStore: mockReadStore)
    }

    override func tearDown() {
        sut = nil
        mockReadStore = nil
        super.tearDown()
    }

    // MARK: - search()

    func test_search_emptyQuery_returnsAllSongs() async {
        mockReadStore.songs = [Song.make(title: "A"), Song.make(title: "B")]
        sut.searchQuery = ""

        await sut.search()

        XCTAssertEqual(sut.searchResults.count, 2)
    }

    func test_search_withQuery_filtersResults() async {
        mockReadStore.songs = [
            Song.make(title: "Bohemian Rhapsody"),
            Song.make(title: "Let It Be")
        ]
        sut.searchQuery = "bohemian"

        await sut.search()

        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(sut.searchResults.first?.title, "Bohemian Rhapsody")
    }

    func test_search_noMatch_returnsEmpty() async {
        mockReadStore.songs = [Song.make(title: "Rock Song")]
        sut.searchQuery = "xyz_no_match"

        await sut.search()

        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    // MARK: - filterByArtist()

    func test_filterByArtist_updatesArtistFilter() async {
        mockReadStore.songs = [
            Song.make(artist: "Queen"),
            Song.make(artist: "ABBA")
        ]

        await sut.filterByArtist("Queen")

        XCTAssertEqual(sut.selectedArtist, "Queen")
        XCTAssertEqual(sut.searchResults.count, 1)
    }

    // MARK: - filterByAlbum()

    func test_filterByAlbum_updatesAlbumFilter() async {
        mockReadStore.songs = [
            Song.make(album: "Abbey Road"),
            Song.make(album: "Let It Be")
        ]

        await sut.filterByAlbum("Abbey Road")

        XCTAssertEqual(sut.selectedAlbum, "Abbey Road")
        XCTAssertEqual(sut.searchResults.count, 1)
    }

    // MARK: - clearFilters()

    func test_clearFilters_resetsAllFilters() async {
        sut.searchQuery = "test"
        await sut.filterByArtist("Queen")

        await sut.clearFilters()

        XCTAssertNil(sut.selectedArtist)
        XCTAssertNil(sut.selectedAlbum)
        XCTAssertFalse(sut.downloadedOnly)
    }

    // MARK: - toggleDownloadedOnly()

    func test_toggleDownloadedOnly_filtersToDownloaded() async {
        mockReadStore.songs = [
            Song.make(isDownloaded: true),
            Song.make(isDownloaded: false)
        ]

        await sut.toggleDownloadedOnly()

        XCTAssertTrue(sut.downloadedOnly)
    }

    // MARK: - changeSortOption()

    func test_changeSortOption_updatesOption() async {
        mockReadStore.songs = [Song.make()]

        await sut.changeSortOption(.playCount)

        XCTAssertEqual(sut.sortOption, .playCount)
    }

    // MARK: - ReadStore reactivity

    func test_readStoreChanges_reRunsLastSearch() async {
        mockReadStore.songs = [Song.make(title: "A")]
        sut.searchQuery = "a"
        await sut.search()
        XCTAssertEqual(sut.searchResults.count, 1)

        mockReadStore.songs = [Song.make(title: "A"), Song.make(title: "Aa")]
        mockReadStore.simulateChange()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.searchResults.count, 2)
    }
}
