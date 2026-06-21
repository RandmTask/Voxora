import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlaybackController: NSObject, AVAudioPlayerDelegate {
  private(set) var playingNoteID: UUID?
  private var player: AVAudioPlayer?

  func toggle(note: AudioNote) {
    if playingNoteID == note.id {
      stop()
      return
    }

    do {
      let url = try AudioFileStore.directoryURL().appending(path: note.audioFileName)
      player = try AVAudioPlayer(contentsOf: url)
      player?.delegate = self
      player?.prepareToPlay()
      player?.play()
      playingNoteID = note.id
    } catch {
      stop()
    }
  }

  func stop() {
    player?.stop()
    player = nil
    playingNoteID = nil
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in stop() }
  }
}
