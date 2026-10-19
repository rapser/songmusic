//
//  DownloadFileStore.swift
//  sinkmusic
//
//  Infrastructure Layer
//

import Foundation

/// Implementación de `DownloadFileStoreProtocol` sobre `FileManager`.
/// Único punto de la app que conoce la disposición `<base>/Music/<uuid>.m4a`.
/// Solo guarda la ruta base, así que conforma a `Sendable` sin `@unchecked`.
final class DownloadFileStore: DownloadFileStoreProtocol, Sendable {

    private static let musicFolderName = "Music"
    private static let fileExtension = "m4a"

    /// Carpeta que contiene `Music/`.
    ///
    /// Se recibe en vez de derivarse aquí dentro. Cuando la derivaba, cualquiera que
    /// construyera un `DownloadFileStore()` apuntaba a la carpeta de música **real**, tests
    /// incluidos: los de `PlayerUseCases`/`PlayerViewModel` escribían ahí sus archivos de
    /// prueba y luego borraban el directorio entero, o sea las descargas del usuario.
    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    /// La ubicación real de la app: `Documents/`. La usa el `DIContainer`.
    static func documents() -> DownloadFileStore {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return DownloadFileStore(baseDirectory: base)
    }

    private var musicDirectory: URL {
        baseDirectory.appendingPathComponent(Self.musicFolderName)
    }

    /// Devuelve la ruta del archivo y, de paso, garantiza que exista `<base>/Music/`.
    /// El crear el directorio aquí (best-effort, como hacía cada DataSource por su cuenta antes
    /// de unificarse en P1.6) permite que la ruta se use directo como destino de escritura.
    func fileURL(for songID: UUID) -> URL {
        let directory = musicDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(songID.uuidString)
            .appendingPathExtension(Self.fileExtension)
    }

    func existingFileURL(for songID: UUID) -> URL? {
        let url = fileURL(for: songID)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

