import Foundation

@main struct SafetyStateTests {
    @MainActor static func main() async throws {
        precondition(ResourceSnapshot.diskCondition(free: 50, total: 1000) == .normal)
        precondition(ResourceSnapshot.diskCondition(free: 49, total: 1000) == .warning)
        precondition(ResourceSnapshot.diskCondition(free: 10, total: 1000) == .critical)
        precondition(ResourceSnapshot.diskCondition(free: 0, total: 0) == .unavailable)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratorSafety-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = UserDefaults(suiteName: "GeneratorSafety-" + UUID().uuidString)!
        let model = StudioModel(rootOverride: root, preferences: prefs, restoreQueue: false)
        var sample = ResourceSnapshot(); sample.diskFree = 100; sample.diskTotal = 1000; sample.condition = .normal
        model.resourceSampler = { _ in sample }
        var alarms = 0; model.alarmPlayer = { alarms += 1 }
        let worker = Process(), ready = Pipe()
        worker.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        worker.arguments = ["-u", "-c", "import os,time\ntry:\n os.setsid()\nexcept PermissionError:\n pass\nprint('ready',flush=True)\ntime.sleep(30)"]
        worker.standardOutput = ready; try worker.run()
        precondition(String(data: ready.fileHandleForReading.availableData, encoding: .utf8)?.contains("ready") == true)
        model.engine = worker; model.isBusy = true
        sample.diskFree = 10; sample.condition = .critical; model.updateResources()
        worker.waitUntilExit()
        precondition(worker.terminationStatus != 0 && !worker.isRunning)
        model.engine = nil; model.isBusy = false; model.safetyStopReason = nil
        sample.diskFree = 100; sample.condition = .normal; model.updateResources(); alarms = 0
        print("PASS: critical-disk stop terminates an owned isolated worker process")
        func item(_ title: String) -> QueueItem {
            QueueItem(id: UUID().uuidString, spec: SongRequest(title: title, caption: "Music", duration: 10, instrumental: true), state: "waiting", attempts: 0)
        }
        let first = item("<script>alert(1)</script>"), next = item("Następny")
        model.musicQueue = MusicQueue(id: UUID().uuidString, title: "Test bezpieczeństwa", items: [first,next], storageVersion: 3)
        model.generationExecutor = { request, id, folder in
            try await Task.sleep(nanoseconds: 100_000_000)
            let file = folder!.appendingPathComponent(id! + ".mp3"); try Data("fake audio".utf8).write(to: file)
            return Song(id: id!, title: request.title, caption: request.caption, lyrics: "", duration: 10,
                        bpm: 100, language: "pl", seed: 1, audioPath: file.path, createdAt: "test", format: "mp3", jobID: id)
        }
        model.startQueue()
        while model.activeQueueItemID == nil { try await Task.sleep(nanoseconds: 1_000_000) }
        sample.diskFree = 10; sample.condition = .critical
        model.updateResources(); model.updateResources()
        precondition(alarms == 1 && model.safetyStopReason != nil)
        while model.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(model.musicQueue!.items.map(\.state) == ["waiting","waiting"])
        precondition(model.musicQueue!.items[1].attempts == 0, "Critical disk must prevent starting the next song")
        precondition(model.cleanupTasks.isEmpty)
        model.startQueue(); precondition(!model.queueRunning, "Critical disk must block a restart")
        sample.diskFree = 100; sample.condition = .normal; model.updateResources()
        model.startQueue()
        while model.queueRunning { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(model.musicQueue?.completedCount == 2)
        precondition(model.musicQueue?.cleanupState == "pending")
        precondition((model.musicQueue!.cleanupDeadline! - Date().timeIntervalSince1970) > 29)
        let html = try String(contentsOf: model.latestReportURL!, encoding: .utf8)
        precondition(!html.contains("<script>alert(1)</script>") && html.contains("&lt;script&gt;"))
        model.keepQueueHelpers()
        precondition(model.musicQueue?.cleanupState == "cancelled")
        print("PASS: disk thresholds, one alarm per critical transition, mid-song pause, restart guard and resume")
        print("PASS: cleanup scheduled after all songs with 30-second delay, cancellation, escaped durable report")
    }
}
