//
//  DominantColorServiceTests.swift
//  sinkmusicTests
//
//  El análisis de la carátula no tenía ningún test: estaba escondido en una extensión de
//  `SwiftUI.Color` y solo se ejercitaba pintando una lista.
//

import XCTest
import UIKit
@testable import sinkmusic

final class DominantColorServiceTests: XCTestCase {

    /// Imagen de un solo color, del tamaño de un thumbnail de lista.
    @MainActor
    private func imageData(red: Double, green: Double, blue: Double) -> Data {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }

    // MARK: - Entradas que no dan color

    func test_extract_withNilData_isNil() {
        XCTAssertNil(DominantColorService.extract(from: nil))
    }

    func test_extract_withDataThatIsNotAnImage_isNil() {
        XCTAssertNil(DominantColorService.extract(from: Data([0x00, 0x01, 0x02])))
    }

    /// Una carátula completamente negra no tiene ningún píxel utilizable: se descartan por
    /// ser demasiado oscuros, y sin muestras no hay color que devolver.
    @MainActor
    func test_extract_fromABlackImage_isNil() {
        XCTAssertNil(DominantColorService.extract(from: imageData(red: 0, green: 0, blue: 0)))
    }

    @MainActor
    func test_extract_fromAWhiteImage_isNil() {
        XCTAssertNil(DominantColorService.extract(from: imageData(red: 1, green: 1, blue: 1)))
    }

    // MARK: - Matiz

    /// El matiz se conserva: un rojo sigue saliendo rojo.
    @MainActor
    func test_extract_keepsTheHue() throws {
        let color = try XCTUnwrap(DominantColorService.extract(from: imageData(red: 1, green: 0, blue: 0)))

        XCTAssertGreaterThan(color.red, 0.6)
        XCTAssertLessThan(color.green, 0.2)
        XCTAssertLessThan(color.blue, 0.2)
    }

    @MainActor
    func test_extract_fromAGrayImage_staysGray() throws {
        let color = try XCTUnwrap(DominantColorService.extract(from: imageData(red: 0.5, green: 0.5, blue: 0.5)))

        XCTAssertEqual(color.red, color.green, accuracy: 0.05)
        XCTAssertEqual(color.green, color.blue, accuracy: 0.05)
    }

    // MARK: - Brillo acotado

    /// Un color muy brillante se baja: con un fondo casi blanco el texto del reproductor
    /// se vuelve ilegible.
    @MainActor
    func test_extract_fromABrightColor_capsTheBrightness() throws {
        let color = try XCTUnwrap(DominantColorService.extract(from: imageData(red: 1, green: 1, blue: 0)))

        XCTAssertLessThanOrEqual(max(color.red, color.green, color.blue), 0.8)
    }

    /// Y uno apagado se sube, por el mismo motivo al revés.
    @MainActor
    func test_extract_fromADimColor_raisesTheBrightness() throws {
        let color = try XCTUnwrap(DominantColorService.extract(from: imageData(red: 0.4, green: 0.1, blue: 0.1)))

        XCTAssertGreaterThanOrEqual(max(color.red, color.green, color.blue), 0.45)
    }

    // MARK: - Fuera del main actor

    /// Se llama desde `Task.detached` y desde la ingesta: debe funcionar sin el main actor.
    func test_extract_runsOffTheMainActor() async throws {
        let data = await MainActor.run { imageData(red: 0.2, green: 0.5, blue: 0.9) }

        let color = await Task.detached { DominantColorService.extract(from: data) }.value

        let unwrapped = try XCTUnwrap(color)
        XCTAssertGreaterThan(unwrapped.blue, unwrapped.red)
    }
}
