//
//  LiveActivityService.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import Foundation
import ActivityKit
import UIKit
import os

/// Servicio para manejar Live Activities (Dynamic Island)
@MainActor
class LiveActivityService: LiveActivityServiceProtocol {
    private let logger = Logger(subsystem: "com.rapser.musicaapp", category: "LiveActivity")
    private var currentActivity: Activity<MusicPlayerActivityAttributes>?

    /// Inicia una Live Activity para la canción actual
    func startActivity(songID: UUID, songTitle: String, artistName: String, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval, artworkThumbnail: Data?) {
        // Si ya hay una actividad, actualizarla en lugar de crear una nueva
        if currentActivity != nil {
            updateActivity(songTitle: songTitle, artistName: artistName, isPlaying: isPlaying, currentTime: currentTime, duration: duration, artworkThumbnail: artworkThumbnail)
            return
        }

        // Verificar que las Live Activities estén disponibles
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities no están habilitadas")
            return
        }

        let attributes = MusicPlayerActivityAttributes(songID: songID.uuidString)
        let contentState = MusicPlayerActivityAttributes.ContentState(
            songTitle: songTitle,
            artistName: artistName,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artworkThumbnail: artworkThumbnail
        )

        do {
            let activity = try Activity<MusicPlayerActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            logger.info("Live Activity iniciada: \(songTitle)")
        } catch {
            logger.error("Error al iniciar Live Activity: \(error)")
        }
    }

    /// Actualiza el estado de la Live Activity actual
    func updateActivity(songTitle: String, artistName: String, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval, artworkThumbnail: Data?) {
        guard let activity = currentActivity else { return }

        let contentState = MusicPlayerActivityAttributes.ContentState(
            songTitle: songTitle,
            artistName: artistName,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artworkThumbnail: artworkThumbnail
        )

        Task {
            await activity.update(
                .init(state: contentState, staleDate: nil)
            )
        }
    }

    /// Finaliza la Live Activity actual
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            currentActivity = nil
            logger.info("Live Activity finalizada")
        }
    }

    /// Verifica si hay una Live Activity activa
    var hasActiveActivity: Bool {
        currentActivity != nil
    }
}
