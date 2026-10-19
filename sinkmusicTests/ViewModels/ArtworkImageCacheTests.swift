//
//  ArtworkImageCacheTests.swift
//  sinkmusicTests
//

import XCTest
import UIKit
@testable import sinkmusic

@MainActor
final class ArtworkImageCacheTests: XCTestCase {

    private var sut: ArtworkImageCache!
    private var mockSongRepo: MockSongRepository!

    override func setUp() {
        super.setUp()
        mockSongRepo = MockSongRepository()
        sut = ArtworkImageCache(
            libraryUseCases: LibraryUseCases(
                songRepository: mockSongRepo,
                cloudStorageRepository: MockCloudStorageRepository(),
                credentialsRepository: MockCredentialsRepository(),
                playlistRepository: MockPlaylistRepository()
            )
        )
    }

    override func tearDown() {
        sut = nil
        mockSongRepo = nil
        super.tearDown()
    }

    /// Carátula cuadrada de `side` píxeles, como la que trae un archivo real.
    private func artwork(side: CGFloat) -> Data {
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: {
                let format = UIGraphicsImageRendererFormat.default()
                format.scale = 1 // píxeles, no puntos: el tamaño debe ser exacto
                return format
            }()
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        return image.pngData()!
    }

    // MARK: - Decodificación al tamaño pedido

    /// El punto de todo esto: la tarjeta de Inicio necesita ~465 px y el thumbnail que
    /// viaja en `SongUI` son 64. Aquí se comprueba que lo que entrega la caché es grande.
    func test_image_decodesBigEnoughForTheCard() async throws {
        let song = Song.make(artworkData: artwork(side: 1000))
        mockSongRepo.songs = [song]

        let decoded = await sut.image(for: song.id)
        let image = try XCTUnwrap(decoded)

        XCTAssertGreaterThan(image.cgImage!.width, 400, "Debe superar con holgura los 64 px del thumbnail")
        XCTAssertLessThanOrEqual(image.cgImage!.width, ArtworkImageCache.cardMaxPixelSize)
    }

    /// No amplía: una carátula de origen pequeña se queda como está en vez de inventarse
    /// píxeles.
    func test_image_withSmallSourceArtwork_doesNotUpscale() async throws {
        let song = Song.make(artworkData: artwork(side: 120))
        mockSongRepo.songs = [song]

        let decoded = await sut.image(for: song.id)
        let image = try XCTUnwrap(decoded)

        XCTAssertEqual(image.cgImage!.width, 120)
    }

    // MARK: - Sin carátula

    func test_image_songWithoutArtwork_isNil() async {
        let song = Song.make(artworkData: nil)
        mockSongRepo.songs = [song]

        let image = await sut.image(for: song.id)

        XCTAssertNil(image, "Quien llama se queda con su thumbnail")
    }

    func test_image_songNotInLibrary_isNil() async {
        let image = await sut.image(for: UUID())

        XCTAssertNil(image)
    }

    // MARK: - Caché

    /// La segunda vez no debe volver a leer de la base de datos ni a decodificar: el
    /// carrusel vuelve a pedir la misma carátula cada vez que una tarjeta reaparece.
    func test_image_secondCall_doesNotHitTheRepositoryAgain() async throws {
        let song = Song.make(artworkData: artwork(side: 600))
        mockSongRepo.songs = [song]

        _ = await sut.image(for: song.id)
        let callsAfterFirst = mockSongRepo.getByIDCallCount
        _ = await sut.image(for: song.id)

        XCTAssertEqual(mockSongRepo.getByIDCallCount, callsAfterFirst)
    }

    func test_image_secondCall_returnsTheSameImage() async throws {
        let song = Song.make(artworkData: artwork(side: 600))
        mockSongRepo.songs = [song]

        let firstCall = await sut.image(for: song.id)
        let secondCall = await sut.image(for: song.id)
        let first = try XCTUnwrap(firstCall)
        let second = try XCTUnwrap(secondCall)

        XCTAssertIdentical(first, second)
    }
}
