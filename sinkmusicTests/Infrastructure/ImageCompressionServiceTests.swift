//
//  ImageCompressionServiceTests.swift
//  sinkmusicTests
//
//  El pipeline de descarga generaba thumbnails decodificando la portada embebida a
//  resolución completa (dos veces) — coste proporcional al tamaño de la portada. Ahora
//  usa downsampling al decodificar. Estos tests fijan el contrato: salida pequeña y con
//  el lado acotado, sin importar lo grande que sea el origen.
//

import XCTest
import UIKit
@testable import sinkmusic

final class ImageCompressionServiceTests: XCTestCase {

    /// Genera un JPEG sintético de `side`×`side` con contenido no uniforme (para que no
    /// comprima a casi nada por sí solo).
    private func bigJPEG(side: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            for i in 0..<40 {
                let f = CGFloat(i) / 40
                ctx.cgContext.setFillColor(UIColor(hue: f, saturation: 1, brightness: 1, alpha: 1).cgColor)
                ctx.cgContext.fill(CGRect(x: 0, y: side * f / 1, width: side, height: side / 40))
                ctx.cgContext.fill(CGRect(x: side * f, y: 0, width: side / 40, height: side))
            }
        }
        return image.jpegData(compressionQuality: 1.0)!
    }

    func test_createThumbnail_boundedSizeAndDimensions() throws {
        let source = bigJPEG(side: 2000)

        let data = try XCTUnwrap(ImageCompressionService.createThumbnail(from: source))
        let image = try XCTUnwrap(UIImage(data: data))

        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, 32)
        XCTAssertLessThanOrEqual(data.count, 4096, "thumbnail muy grande: \(data.count) B")
        XCTAssertLessThan(data.count, source.count)
    }

    func test_createMediumThumbnail_boundedSizeAndDimensions() throws {
        let source = bigJPEG(side: 2000)

        let data = try XCTUnwrap(ImageCompressionService.createMediumThumbnail(from: source))
        let image = try XCTUnwrap(UIImage(data: data))

        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, 64)
        XCTAssertLessThanOrEqual(data.count, 12_288, "medium thumbnail muy grande: \(data.count) B")
    }

    func test_makeThumbnails_producesBoth() throws {
        let (small, medium) = ImageCompressionService.makeThumbnails(from: bigJPEG(side: 1200))
        XCTAssertNotNil(small)
        XCTAssertNotNil(medium)
    }

    func test_garbageData_returnsNilWithoutCrashing() {
        XCTAssertNil(ImageCompressionService.createThumbnail(from: Data([0x00, 0x01, 0x02, 0x03])))
        XCTAssertNil(ImageCompressionService.createMediumThumbnail(from: Data()))
        let (s, m) = ImageCompressionService.makeThumbnails(from: Data([0xFF, 0xD8, 0x00]))
        XCTAssertNil(s)
        XCTAssertNil(m)
    }
}
