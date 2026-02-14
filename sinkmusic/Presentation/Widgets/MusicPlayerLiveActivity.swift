//
//  MusicPlayerLiveActivity.swift
//  sinkmusic
//
//  Created by miguel tomairo on 6/09/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity para mostrar el reproductor de música en el Dynamic Island y pantalla de bloqueo
struct MusicPlayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicPlayerActivityAttributes.self) { context in
            // Vista para la pantalla de bloqueo (cuando el iPhone está bloqueado)
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Vista expandida (cuando el usuario mantiene presionado el Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    // Artwork o icono de música
                    if let thumbnailData = context.state.artworkThumbnail,
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appPurple)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Controles de reproducción
                    HStack(spacing: 16) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        }

                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }

                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    // Información de la canción
                    VStack(spacing: 4) {
                        Text(context.state.songTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(context.state.artistName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // Barra de progreso
                    ProgressView(value: context.state.currentTime, total: context.state.duration)
                        .tint(.appPurple)
                }
            } compactLeading: {
                // Vista compacta izquierda (icono pequeño)
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                    .foregroundColor(.appPurple)
            } compactTrailing: {
                // Vista compacta derecha (waveform animado)
                if context.state.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(.appPurple)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else {
                    Image(systemName: "waveform")
                        .foregroundColor(.gray)
                }
            } minimal: {
                // Vista mínima (cuando hay múltiples Live Activities)
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                    .foregroundColor(.appPurple)
            }
        }
    }
}

/// Vista para la pantalla de bloqueo
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<MusicPlayerActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Artwork o icono de música
            if let thumbnailData = context.state.artworkThumbnail,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appPurple)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.songTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(context.state.artistName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)

                // Barra de progreso
                ProgressView(value: context.state.currentTime, total: context.state.duration)
                    .tint(.appPurple)
            }

            Spacer()

            // Botón play/pause
            Button(intent: PlayPauseIntent()) {
                Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .activityBackgroundTint(Color.appDark)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - App Intents para controlar la reproducción desde Live Activity

import AppIntents

struct PlayPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Play/Pause" }

    func perform() async throws -> some IntentResult {
        // Esta acción será manejada por el PlayerViewModel
        NotificationCenter.default.post(name: .playPauseFromLiveActivity, object: nil)
        return .result()
    }
}

struct NextTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Next Track" }

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .nextTrackFromLiveActivity, object: nil)
        return .result()
    }
}

struct PreviousTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Previous Track" }

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .previousTrackFromLiveActivity, object: nil)
        return .result()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let playPauseFromLiveActivity = Notification.Name("playPauseFromLiveActivity")
    static let nextTrackFromLiveActivity = Notification.Name("nextTrackFromLiveActivity")
    static let previousTrackFromLiveActivity = Notification.Name("previousTrackFromLiveActivity")
}
