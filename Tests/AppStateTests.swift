import Foundation
import AVFoundation

@main struct AppStateTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratorAppState-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioModel(rootOverride: root, preferences: UserDefaults(suiteName: "GeneratorAppState-" + UUID().uuidString)!, restoreQueue: false)
        model.loadingLibrary = true
        model.caption = "Test"
        model.lyrics = "Test"
        model.generate()
        precondition(!model.isBusy && model.bridge == nil, "Generation must wait for library loading")
        model.openAdvanced()
        precondition(!model.isBusy && model.engine == nil, "Panel must wait for library loading")
        model.loadingLibrary = false
        let song = Song(id: "test-result", title: "Nowy utwór", caption: "Test", lyrics: "Test", duration: 30,
                        bpm: 112, language: "pl", seed: 123, audioPath: "/tmp/test.mp3", createdAt: "2026-10-31T20:00:00+00:00", format: "mp3")
        let raw = try JSONEncoder().encode(song)
        let object = try JSONSerialization.jsonObject(with: raw)
        model.isPlaying = true
        model.playbackTime = 12
        model.handleEvent(try JSONSerialization.data(withJSONObject: ["type":"result", "song":object]))
        precondition(model.selectedSong?.id == "test-result")
        precondition(!model.isPlaying && model.playbackTime == 0 && model.playbackDuration == 30)
        precondition(model.receivedResult && model.songs.count == 1)
        model.handleEvent(try JSONSerialization.data(withJSONObject: ["type":"result", "song":object]))
        precondition(model.songs.count == 1, "Same result must not duplicate library entries")
        model.seed = "invalid"; model.generate()
        precondition(model.errorMessage != nil && !model.isBusy)
        model.startGenerationClock(now: 100)
        precondition(StudioModel.generationTimeLabel(model.elapsedGenerationTime(now: 3761.29)) == "01:01:01.2")
        model.finishGenerationClock(now: 3761.29)
        precondition(model.generationStartedAt == nil && model.elapsedGenerationTime(now: 5000) == model.generationElapsed)
        model.startGenerationClock(now: 5000)
        precondition(model.elapsedGenerationTime(now: 5000) == 0)
        model.finishGenerationClock(now: 5000)
        model.outputFolderPath = "/this-folder-does-not-exist/invalid"
        do { try model.validateOutputFolder(); preconditionFailure("Unavailable output folder must fail") } catch {}
        print("PASS: generation clock rollover, stop, reset; unavailable output folder rejected")
        print("PASS: library/generation serialization, result playback reset, duration, deduplication, seed validation")
    }
}
