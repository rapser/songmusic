//
//  DownloadFailure.swift
//  sinkmusic
//
//  Created by Codex.
//  Core Layer - Tipado para errores de descarga
//

import Foundation

/// Clasificación de fallos de descarga para mostrar mensajes más útiles
/// y permitir acciones específicas como reintentar o esperar conectividad.
enum DownloadFailureKind: String, Sendable, Equatable {
    case networkUnavailable
    case cancelled
    case quotaExceeded
    case invalidCredentials
    case fileNotFound
    case invalidFile
    case decryptionFailed
    case storageFailure
    case processingFailed
    case unknown

    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return "Sin conexión. La descarga se reintentará cuando vuelva la red."
        case .cancelled:
            return "Descarga cancelada."
        case .quotaExceeded:
            return "Se alcanzó el límite de transferencia del proveedor."
        case .invalidCredentials:
            return "Faltan credenciales o configuración del proveedor."
        case .fileNotFound:
            return "No se encontró el archivo en la nube."
        case .invalidFile:
            return "El archivo descargado no es válido."
        case .decryptionFailed:
            return "No se pudo desencriptar el archivo."
        case .storageFailure:
            return "No se pudo guardar el archivo en el dispositivo."
        case .processingFailed:
            return "No se pudo procesar la descarga."
        case .unknown:
            return "Ocurrió un error al descargar la canción."
        }
    }

    var shouldSuggestRetry: Bool {
        switch self {
        case .networkUnavailable, .processingFailed, .unknown:
            return true
        case .cancelled, .quotaExceeded, .invalidCredentials, .fileNotFound, .invalidFile, .decryptionFailed, .storageFailure:
            return false
        }
    }
}

/// Fallo tipado de descarga.
struct DownloadFailure: Sendable, Equatable {
    let kind: DownloadFailureKind
    let message: String

    init(kind: DownloadFailureKind, message: String) {
        self.kind = kind
        self.message = message
    }

    init(error: Error) {
        self = DownloadFailureClassifier.classify(error: error)
    }
}

enum DownloadFailureClassifier {
    static func classify(error: Error) -> DownloadFailure {
        if let urlError = error as? URLError {
            return classify(urlError: urlError) ?? DownloadFailure(kind: .unknown, message: urlError.localizedDescription)
        }

        if let cloudError = error as? CloudStorageError {
            switch cloudError {
            case .credentialsNotConfigured, .missingAPIKey, .missingFolderId:
                return DownloadFailure(kind: .invalidCredentials, message: cloudError.localizedDescription)
            case .fileNotFound:
                return DownloadFailure(kind: .fileNotFound, message: cloudError.localizedDescription)
            case .invalidFile:
                return DownloadFailure(kind: .invalidFile, message: cloudError.localizedDescription)
            case .downloadFailed(let underlying):
                return classify(error: underlying)
            case .unsupportedProvider, .providerNotSupported:
                return DownloadFailure(kind: .processingFailed, message: cloudError.localizedDescription)
            }
        }

        if let megaError = error as? MegaError {
            switch megaError {
            case .rateLimitExceeded:
                return DownloadFailure(kind: .quotaExceeded, message: megaError.localizedDescription)
            case .decryptionFailed:
                return DownloadFailure(kind: .decryptionFailed, message: megaError.localizedDescription)
            case .fileNotFound:
                return DownloadFailure(kind: .fileNotFound, message: megaError.localizedDescription)
            case .downloadFailed(let message):
                return DownloadFailure(kind: .processingFailed, message: message)
            case .invalidFolderURL, .invalidFileKey, .apiError:
                return DownloadFailure(kind: .processingFailed, message: megaError.localizedDescription)
            }
        }

        if let syncError = error as? SyncError {
            switch syncError {
            case .invalidCredentials:
                return DownloadFailure(kind: .invalidCredentials, message: "Faltan credenciales del proveedor.")
            case .emptyFolder:
                return DownloadFailure(kind: .fileNotFound, message: "La carpeta no contiene canciones descargables.")
            case .networkError(let message):
                return DownloadFailure(kind: .networkUnavailable, message: message)
            case .invalidAudioFile:
                return DownloadFailure(kind: .invalidFile, message: "El archivo descargado no es un audio válido.")
            }
        }

        if let downloadError = error as? DownloadError {
            switch downloadError {
            case .songNotFound:
                return DownloadFailure(kind: .fileNotFound, message: "La canción no existe en la base de datos.")
            case .alreadyDownloaded:
                return DownloadFailure(kind: .processingFailed, message: "La canción ya está descargada.")
            case .notDownloaded:
                return DownloadFailure(kind: .processingFailed, message: "La canción no tiene descarga local.")
            case .downloadFailed:
                return DownloadFailure(kind: .processingFailed, message: "La descarga no pudo completarse.")
            case .metadataExtractionFailed:
                return DownloadFailure(kind: .processingFailed, message: "No se pudo extraer la metadata.")
            }
        }

        if let songError = error as? SongError {
            switch songError {
            case .fileNotFound:
                return DownloadFailure(kind: .fileNotFound, message: songError.localizedDescription)
            case .invalidAudioFile:
                return DownloadFailure(kind: .invalidFile, message: songError.localizedDescription)
            case .downloadFailed:
                return DownloadFailure(kind: .processingFailed, message: songError.localizedDescription)
            case .metadataExtractionFailed:
                return DownloadFailure(kind: .processingFailed, message: songError.localizedDescription)
            case .notDownloaded, .alreadyDownloading, .invalidURL:
                return DownloadFailure(kind: .processingFailed, message: songError.localizedDescription)
            }
        }

        return classify(urlError: error as? URLError)
            ?? DownloadFailure(kind: .unknown, message: error.localizedDescription)
    }

    private static func classify(urlError: URLError?) -> DownloadFailure? {
        guard let urlError else { return nil }

        switch urlError.code {
        case .cancelled:
            return DownloadFailure(kind: .cancelled, message: urlError.localizedDescription)
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return DownloadFailure(kind: .networkUnavailable, message: urlError.localizedDescription)
        default:
            return DownloadFailure(kind: .unknown, message: urlError.localizedDescription)
        }
    }
}
