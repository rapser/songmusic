//
//  ReconcileDownloadsUseCaseTests.swift
//  sinkmusicTests
//
//  El estado que provocó la incidencia: 81 canciones con `isDownloaded = true` y 33
//  archivos en disco. Las 48 restantes quedaban muertas — `play` fallaba con
//  `fileNotDownloaded` y la descarga se negaba con `alreadyDownloaded`.
//

import XCTest
@testable import sinkmusic

/// Store en memoria: decide qué canciones "tienen archivo" sin tocar el disco.
private struct StubFileStore: DownloadFileStoreProtocol {
    let present: Set<UUID>

    func fileURL(for songID: UUID) -> URL {
        URL(fileURLWithPath: "/tmp/Music/\(songID.uuidString).m4a")
    }

    func existingFileURL(for songID: UUID) -> URL? {
        present.contains(songID) ? fileURL(for: songID) : nil
    }
}

@MainActor
final class ReconcileDownloadsUseCaseTests: XCTestCase {

    private var songRepository: MockSongRepository!

    override func setUp() {
        super.setUp()
        songRepository = MockSongRepository()
    }

    override func tearDown() {
        songRepository = nil
        super.tearDown()
    }

    private func makeSong(isDownloaded: Bool, title: String = "S") -> Song {
        Song(id: UUID(), title: title, artist: "A", album: nil, author: nil,
             fileID: "f-\(UUID().uuidString)", isDownloaded: isDownloaded, duration: 217,
             artworkData: Data([1, 2, 3]), artworkThumbnail: nil, artworkMediumThumbnail: nil,
             playCount: 7, lastPlayedAt: nil, dominantColor: nil)
    }

    private func makeSUT(filesOnDisk: Set<UUID>) -> ReconcileDownloadsUseCase {
        ReconcileDownloadsUseCase(
            songRepository: songRepository,
            fileStore: StubFileStore(present: filesOnDisk)
        )
    }

    func test_songWithoutFile_isMarkedAsNotDownloaded() async throws {
        let ghost = makeSong(isDownloaded: true, title: "Be My Lover")
        songRepository.songs = [ghost]

        let reconciled = try await makeSUT(filesOnDisk: []).execute()

        XCTAssertEqual(reconciled, [ghost.id])
        XCTAssertFalse(try XCTUnwrap(songRepository.songs.first).isDownloaded)
    }

    func test_songWithFile_isLeftAlone() async throws {
        let real = makeSong(isDownloaded: true)
        songRepository.songs = [real]

        let reconciled = try await makeSUT(filesOnDisk: [real.id]).execute()

        XCTAssertTrue(reconciled.isEmpty)
        XCTAssertTrue(try XCTUnwrap(songRepository.songs.first).isDownloaded)
    }

    /// Solo se toca la bandera: la canción vuelve a ser descargable sin que la biblioteca
    /// pierda la carátula, la duración ni las reproducciones acumuladas.
    func test_metadataIsPreserved() async throws {
        let ghost = makeSong(isDownloaded: true)
        songRepository.songs = [ghost]

        _ = try await makeSUT(filesOnDisk: []).execute()

        let fixed = try XCTUnwrap(songRepository.songs.first)
        XCTAssertEqual(fixed.duration, 217)
        XCTAssertEqual(fixed.artworkData, Data([1, 2, 3]))
        XCTAssertEqual(fixed.playCount, 7)
        XCTAssertEqual(fixed.title, ghost.title)
    }

    /// El caso real: una parte de la biblioteca conserva su archivo y el resto no.
    func test_reconcilesOnlyTheOnesMissingTheirFile() async throws {
        let withFile = (0..<3).map { makeSong(isDownloaded: true, title: "ok-\($0)") }
        let ghosts = (0..<5).map { makeSong(isDownloaded: true, title: "ghost-\($0)") }
        songRepository.songs = withFile + ghosts

        let reconciled = try await makeSUT(filesOnDisk: Set(withFile.map(\.id))).execute()

        XCTAssertEqual(Set(reconciled), Set(ghosts.map(\.id)))
        XCTAssertEqual(songRepository.songs.filter(\.isDownloaded).count, 3)
    }

    /// Las que ya estaban pendientes no se miran: no tienen archivo por definición.
    func test_pendingSongsAreNotTouched() async throws {
        let pending = makeSong(isDownloaded: false)
        songRepository.songs = [pending]

        let reconciled = try await makeSUT(filesOnDisk: []).execute()

        XCTAssertTrue(reconciled.isEmpty)
    }

    func test_emptyLibrary_doesNothing() async throws {
        let reconciled = try await makeSUT(filesOnDisk: []).execute()

        XCTAssertTrue(reconciled.isEmpty)
    }
}
