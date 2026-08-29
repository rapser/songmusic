//
//  AudioInterruptionObserver.swift
//  sinkmusic
//
//  Infrastructure — reacciona a las interrupciones de `AVAudioSession` (llamadas, Siri,
//  otra app que toma el audio): pausa al empezar y reanuda al terminar si procede.
//  Extraído de `AudioPlayerService` (P2.13).
//

import Foundation
import AVFoundation

/// Lo que el observador necesita del reproductor para pausar/reanudar ante una interrupción.
@MainActor
protocol AudioInterruptionDelegate: AnyObject {
    var isPlaying: Bool { get }
    var currentSongID: UUID? { get }
    func pauseForInterruption()
    /// Reanuda; devuelve `false` si el motor no tenía nada cargado.
    @discardableResult
    func resumeAfterInterruption() -> Bool
}

@MainActor
final class AudioInterruptionObserver {

    private let eventBus: EventBusProtocol
    /// Espera antes de reanudar tras una interrupción (evita competir con la app que la causó).
    private let resumeDelay: Duration
    private weak var delegate: AudioInterruptionDelegate?
    private var wasPlayingBeforeInterruption = false

    // El token no es Sendable y `removeObserver` es seguro desde cualquier hilo.
    private nonisolated(unsafe) var token: NSObjectProtocol?

    init(eventBus: EventBusProtocol, resumeDelay: Duration = .seconds(1)) {
        self.eventBus = eventBus
        self.resumeDelay = resumeDelay
    }

    func start(delegate: AudioInterruptionDelegate) {
        self.delegate = delegate
        token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            // `Notification` no es Sendable: se extraen valores primitivos aquí, antes del
            // hop a MainActor (se pasan `UInt`/`Bool`, no tipos de AVFoundation).
            guard let parsed = Self.parse(note) else { return }
            let (rawType, shouldResume) = parsed
            Task { @MainActor [weak self] in
                await self?.handle(rawType: rawType, shouldResume: shouldResume)
            }
        }
    }

    private nonisolated static func parse(_ note: Notification) -> (rawType: UInt, shouldResume: Bool)? {
        guard let userInfo = note.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return nil
        }
        var shouldResume = false
        if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            } else {
                shouldResume = true
            }
        }
        return (typeValue, shouldResume)
    }

    /// `internal` para poder probarlo sin postear notificaciones reales de `AVAudioSession`.
    func handle(rawType: UInt, shouldResume: Bool) async {
        guard let delegate, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            if delegate.isPlaying {
                wasPlayingBeforeInterruption = true
                delegate.pauseForInterruption()
            }

        case .ended:
            guard wasPlayingBeforeInterruption, shouldResume else {
                wasPlayingBeforeInterruption = false
                return
            }
            try? await Task.sleep(for: resumeDelay)
            guard let songID = delegate.currentSongID else { return }
            if !delegate.resumeAfterInterruption() {
                eventBus.emit(.stateChanged(isPlaying: false, songID: songID))
            }
            wasPlayingBeforeInterruption = false

        @unknown default:
            break
        }
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
