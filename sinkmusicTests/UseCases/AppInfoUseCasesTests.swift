//
//  AppInfoUseCasesTests.swift
//  sinkmusicTests
//

import XCTest
@testable import sinkmusic

@MainActor
final class AppInfoUseCasesTests: XCTestCase {

    private var sut: AppInfoUseCases!

    override func setUp() {
        super.setUp()
        sut = AppInfoUseCases()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_getAppInfo_returnsDisplayName() {
        XCTAssertEqual(sut.getAppInfo().displayName, "SinkMusic")
    }

    /// El `Bundle` se inyecta: con el de los tests (que no trae las claves de versión)
    /// deben salir los valores de respaldo en vez de cadenas vacías.
    func test_getAppInfo_withABundleWithoutVersionKeys_fallsBack() {
        let info = sut.getAppInfo(bundle: Bundle(for: type(of: self)))

        XCTAssertFalse(info.version.isEmpty)
        XCTAssertFalse(info.build.isEmpty)
        XCTAssertEqual(info.displayName, "SinkMusic")
    }

    func test_appInfo_fullVersion_combinesVersionAndBuild() {
        let info = AppInfo(version: "1.0.0", build: "19", displayName: "SinkMusic")

        XCTAssertEqual(info.fullVersion, "1.0.0 (19)")
    }
}
