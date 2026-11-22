import Foundation

@main struct QueueStateTests {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratorQueueTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "GeneratorQueueTests-" + UUID().uuidString
        let prefs = UserDefaults(suiteName: suite)!
        defer { prefs.removePersistentDomain(forName: suite) }
        func item(_ title: String) -> QueueItem {
            QueueItem(id: UUID().uuidString, spec: SongRequest(title: title, caption: "Club", duration: 10, instrumental: true), state: "waiting", attempts: 0)
        }
        func result(_ request: SongRequest, _ id: String?, _ output: URL?) throws -> Song {
            let file = output!.appendingPathComponent(id! + ".mp3")
            try Data("test audio".utf8).write(to: file)
            return Song(id: UUID().uuidString, title: request.title, caption: request.caption, lyrics: "", duration: 10,
                        bpm: 128, language: "pl", seed: 12, audioPath: file.path, createdAt: "2026-10-31", format: "mp3", jobID: id)
        }
        let one = item("Pierwszy"), two = item("Drugi")
        let model = StudioModel(rootOverride: root, preferences: prefs, restoreQueue: false)
        model.musicQueue = MusicQueue(id: UUID().uuidString, title: "Pause and resume", items: [one, two])
        var firstCalls: [String] = []
        model.generationExecutor = { request, id, output in
            firstCalls.append(id!)
            model.requestQueuePause()
            return try result(request, id, output)
        }
        model.startQueue()
        while model.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(firstCalls == [one.id])
        precondition(model.musicQueue?.completedCount == 1 && model.musicQueue?.waitingCount == 1)
        precondition(model.generationStartedAt == nil && !model.isBusy)
        let restored = StudioModel(rootOverride: root, preferences: prefs)
        precondition(restored.musicQueue?.completedCount == 1 && restored.musicQueue?.waitingCount == 1)
        var resumedCalls: [String] = []
        restored.generationExecutor = { request, id, output in
            resumedCalls.append(id!); return try result(request, id, output)
        }
        restored.startQueue()
        while restored.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(resumedCalls == [two.id], "Completed first song must never run again")
        precondition(restored.musicQueue?.completedCount == 2)
        print("PASS: serial execution, pause after current song, persisted restart and skip completed jobs")

        let failed = StudioModel(rootOverride: root, preferences: prefs, restoreQueue: false)
        let bad = item("Błąd"), next = item("Następny")
        failed.musicQueue = MusicQueue(id: UUID().uuidString, title: "Errors", items: [bad, next])
        failed.generationExecutor = { _, _, _ in throw StudioFailure(message: "Simulated failure") }
        failed.startQueue()
        while failed.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(failed.musicQueue?.failedCount == 1 && failed.musicQueue?.waitingCount == 1)
        precondition(failed.errorMessage != nil && !failed.isBusy && failed.generationStartedAt == nil)
        failed.retryQueueItem(bad.id)
        precondition(failed.musicQueue?.items[0].id == bad.id && failed.musicQueue?.waitingCount == 2)
        failed.generationExecutor = { request, id, output in try result(request, id, output) }
        failed.startQueue()
        while failed.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(failed.musicQueue?.completedCount == 2 && failed.musicQueue?.failedCount == 0)
        print("PASS: failure pauses queue, retry retains durable job identifier, resumed completion")

        var interrupted = failed.musicQueue!
        interrupted.items[1].state = "running"; interrupted.items[1].result = nil
        try restored.recoverQueue(interrupted)
        precondition(restored.musicQueue!.items[0].state == "completed" && restored.musicQueue!.items[1].state == "waiting")
        try FileManager.default.removeItem(atPath: restored.musicQueue!.items[0].result!.audioPath)
        try restored.recoverQueue(restored.musicQueue!)
        precondition(restored.musicQueue!.items[0].state == "failed")
        print("PASS: interrupted item recovered, unavailable completed file reported without silent regeneration")
    }
}
