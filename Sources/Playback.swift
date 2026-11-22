import Foundation
import AVFoundation

extension StudioModel {
    func play(_ song: Song) {
        if selectedSong?.id == song.id, let player = player {
            if player.isPlaying { player.pause(); isPlaying = false } else { player.play(); isPlaying = true }
            return
        }
        stopPlayback()
        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: song.audioPath))
            player?.prepareToPlay(); player?.play()
            selectedSong = song; isPlaying = true; playbackDuration = player?.duration ?? song.duration
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, let audio = self.player else { return }
                    self.playbackTime = audio.currentTime; self.isPlaying = audio.isPlaying
                }
            }
        } catch { errorMessage = "Nie można odtworzyć pliku: \(error.localizedDescription)" }
    }
    func stopPlayback() {
        player?.stop(); player = nil; timer?.invalidate(); timer = nil
        isPlaying = false; playbackTime = 0; playbackDuration = 0
    }
    func seek(to seconds: Double) {
        player?.currentTime = max(0, min(seconds, player?.duration ?? 0)); playbackTime = player?.currentTime ?? 0
    }
}
