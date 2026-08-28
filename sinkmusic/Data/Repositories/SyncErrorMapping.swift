//
//  SyncErrorMapping.swift
//  sinkmusic
//
//  Data Layer — traduce errores crudos del pipeline cloud (URLSession, data sources)
//  al `SyncError` tipado del dominio. Antes esta clasificación se hacía en el ViewModel
//  con `error.localizedDescription.contains("401")`, frágil y dependiente del idioma.
//

import Foundation

extension SyncError {

    /// Clasifica cualquier `Error` del sync en un caso tipado.
    static func from(_ error: Error) -> SyncError {
        if let syncError = error as? SyncError {
            return syncError
        }

        if let cloudError = error as? CloudStorageError {
            switch cloudError {
            case .credentialsNotConfigured, .missingAPIKey, .missingFolderId:
                return .invalidCredentials
            case .fileNotFound:
                return .emptyFolder
            case .invalidFile:
                return .invalidAudioFile
            case .downloadFailed(let underlying):
                return .from(underlying)
            case .unsupportedProvider, .providerNotSupported:
                return .networkError(cloudError.localizedDescription)
            }
        }

        if let urlError = error as? URLError {
            if let status = (urlError as NSError).userInfo["statusCode"] as? Int {
                switch status {
                case 401, 403: return .invalidCredentials
                case 404: return .emptyFolder
                default: return .networkError("HTTP \(status)")
                }
            }
            switch urlError.code {
            case .userAuthenticationRequired:
                return .invalidCredentials
            default:
                return .networkError(urlError.localizedDescription)
            }
        }

        return .networkError(error.localizedDescription)
    }
}
