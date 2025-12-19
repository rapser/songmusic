//
//  SyncError.swift
//  sinkmusic
//
//  Created by miguel tomairo on 19/12/25.
//


import Foundation

enum SyncError: Error {
    case invalidCredentials
    case emptyFolder
    case networkError(String)
}
