
import Foundation
import AVFoundation
import Combine

// Servicio dedicado a manejar la lógica de AVAudioPlayer
class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    
    // Publishers para que el ViewModel pueda suscribirse a los cambios
    var onPlaybackStateChanged = PassthroughSubject<(isPlaying: Bool, songID: UUID?), Never>()
    var onPlaybackTimeChanged = PassthroughSubject<(time: TimeInterval, duration: TimeInterval), Never>()
    var onSongFinished = PassthroughSubject<Void, Never>()

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentlyPlayingID: UUID?

    func play(songID: UUID, url: URL) {
        if currentlyPlayingID == songID {
            // Si es la misma canción, simplemente reanuda o pausa
            if audioPlayer?.isPlaying == false {
                audioPlayer?.play()
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: self.currentlyPlayingID))
            }
        } else {
            // Es una canción nueva
            do {
                print("🔍 Intentando reproducir archivo desde la ruta: \(url.path)") // Log para depuración
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                
                self.currentlyPlayingID = songID
                startPlaybackTimer()
                onPlaybackStateChanged.send((isPlaying: true, songID: self.currentlyPlayingID))
            } catch {
                print("Error al iniciar AVAudioPlayer: \(error.localizedDescription)")
                onPlaybackStateChanged.send((isPlaying: false, songID: nil))
            }
        }
    }

    func pause() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        onPlaybackStateChanged.send((isPlaying: false, songID: self.currentlyPlayingID))
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        let oldID = currentlyPlayingID
        currentlyPlayingID = nil
        onPlaybackStateChanged.send((isPlaying: false, songID: oldID))
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.onPlaybackTimeChanged.send((time: player.currentTime, duration: player.duration))
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedSongID = currentlyPlayingID
        currentlyPlayingID = nil
        onPlaybackStateChanged.send((isPlaying: false, songID: finishedSongID))
        onSongFinished.send(())
    }
}
