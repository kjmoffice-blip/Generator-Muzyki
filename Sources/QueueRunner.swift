import Foundation
import AppKit
import UniformTypeIdentifiers

extension StudioModel {
    var queueDirectory: URL { root.appendingPathComponent("Kolejki", isDirectory: true) }

    func validateQueue(_ value: MusicQueue) throws {
        guard UUID(uuidString: value.id) != nil, !value.items.isEmpty, value.items.count <= 1000,
              Set(value.items.map(\.id)).count == value.items.count else {
            throw StudioFailure(message: "Nieprawidłowa zapisana kolejka.")
        }
        for item in value.items {
            guard UUID(uuidString: item.id) != nil, ["waiting", "running", "completed", "failed"].contains(item.state),
                  item.spec.duration.isFinite, (10...300).contains(item.spec.duration),
                  !item.spec.title.isEmpty, !item.spec.caption.isEmpty,
                  item.spec.instrumental || !item.spec.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StudioFailure(message: "Nieprawidłowa pozycja w kolejce: \(item.spec.title).")
            }
        }
    }

    func storeQueue() throws {
        guard var value = musicQueue else { return }
        if queueStartedAt != nil { value.elapsed = elapsedQueueTime() }
        try validateQueue(value)
        try FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(value)
        try encoded.write(to: queueDirectory.appendingPathComponent(value.id + ".json"), options: .atomic)
        try encoded.write(to: queueDirectory.appendingPathComponent("Biezaca-kolejka.json"), options: .atomic)
    }

    func recoverQueue(_ value: MusicQueue) throws {
        try validateQueue(value)
        var restored = value
        for index in restored.items.indices {
            if restored.items[index].state == "running" {
                restored.items[index].state = "waiting"
                restored.items[index].error = "Przerwano poprzednią sesję. Możesz wznowić tę pozycję."
            }
            if restored.items[index].state == "completed" {
                let path = restored.items[index].result?.audioPath ?? ""
                if path.isEmpty || !FileManager.default.fileExists(atPath: path) {
                    restored.items[index].state = "failed"
                    restored.items[index].error = "Zapisany plik jest niedostępny. Podłącz dysk albo użyj Ponów, aby utworzyć nowy wynik."
                }
            }
        }
        musicQueue = restored
    }

    func restoreCurrentQueue() {
        let file = queueDirectory.appendingPathComponent("Biezaca-kolejka.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            try recoverQueue(JSONDecoder().decode(MusicQueue.self, from: Data(contentsOf: file)))
        } catch { errorMessage = "Nie udało się odtworzyć kolejki: \(error.localizedDescription)" }
    }

    func choosePlanFile() {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        let panel = NSOpenPanel()
        panel.title = "Wczytaj kolekcję utworów"
        panel.prompt = "Wczytaj listę"
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "docx") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { importPlan(file: url) }
    }

    func importPlan(file: URL? = nil, text: String? = nil) {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        importingPlan = true; errorMessage = nil; importedPlan = nil
        Task {
            do {
                var request: [String: Any] = ["command": "import_plan"]
                if let file = file { request["path"] = file.path } else { request["text"] = text ?? "" }
                try await runBridge(request)
                guard var value = importedPlan else { throw StudioFailure(message: "Nie odczytano listy utworów.") }
                value.kind = "sos-music-queue"; value.version = 1; value.elapsed = 0; value.storageVersion = 3
                try validateQueue(value)
                // Save the old collection as well; importing another list never deletes its progress.
                try storeQueue()
                musicQueue = value
                try storeQueue()
                status = "Wczytano listę. Liczba utworów: \(value.items.count). Sprawdź podgląd i uruchom kolejkę."
            } catch { errorMessage = error.localizedDescription }
            importingPlan = false
        }
    }

    func loadSamplePlan() {
        guard let file = Bundle.main.url(forResource: "Przykladowa-kolekcja", withExtension: "txt") else { return }
        importPlan(file: file)
    }

    func openPlanGuide() {
        if let file = Bundle.main.url(forResource: "Instrukcja-list", withExtension: "md") { NSWorkspace.shared.open(file) }
    }

    func chooseSavedQueue() {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        let panel = NSOpenPanel()
        panel.title = "Przywróć zapisaną kolejkę"; panel.prompt = "Przywróć kolejkę"
        panel.allowedContentTypes = [.json]; panel.directoryURL = queueDirectory
        if panel.runModal() == .OK, let file = panel.url {
            do {
                guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 20_000_000 else {
                    throw StudioFailure(message: "Plik zapisanej kolejki jest za duży.")
                }
                let value = try JSONDecoder().decode(MusicQueue.self, from: Data(contentsOf: file))
                try validateQueue(value); try storeQueue(); try recoverQueue(value); try storeQueue()
                errorMessage = nil; status = "Przywrócono kolejkę. Gotowe utwory zostaną pominięte."
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func retryQueueItem(_ id: String? = nil) {
        guard !isBusy, !importingPlan, var value = musicQueue else { return }
        for index in value.items.indices where value.items[index].state == "failed" && (id == nil || value.items[index].id == id) {
            value.items[index].state = "waiting"; value.items[index].error = nil
        }
        musicQueue = value
        do { try storeQueue(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func requestQueuePause() {
        guard queueRunning else { return }
        queuePauseRequested = true
        status = "Pauza nastąpi po zapisaniu bieżącego utworu."
    }

    func elapsedQueueTime(now: Double = ProcessInfo.processInfo.systemUptime) -> Double {
        (musicQueue?.elapsed ?? 0) + (queueStartedAt.map { max(0, now - $0) } ?? 0)
    }

    func startQueue() {
        guard !isBusy, !loadingLibrary, !importingPlan, !queueRunning,
              var value = musicQueue, value.waitingCount > 0 else { return }
        do {
            if let folder = value.outputFolder {
                guard FileManager.default.isWritableFile(atPath: folder) else {
                    throw StudioFailure(message: "Folder tej kolekcji jest niedostępny. Podłącz dysk: \(folder)")
                }
                outputFolderPath = folder
                preferences.set(folder, forKey: "musicOutputFolder")
            }
            try validateOutputFolder()
            try checkDiskBeforeWork()
            value.outputFolder = saveDirectory.path; musicQueue = value
            try storeQueue()
        } catch { errorMessage = error.localizedDescription; return }
        queueRunning = true; queuePauseRequested = false; isBusy = true
        safetyStopReason = nil; peakApplicationMemory = resources.applicationBytes
        errorMessage = nil; stopPlayback()
        queueStartedAt = ProcessInfo.processInfo.systemUptime
        Task { await processQueue() }
    }

    func processQueue() async {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: "Generowanie kolekcji muzycznej")
        defer {
            if musicQueue != nil { musicQueue!.elapsed = elapsedQueueTime() }
            queueStartedAt = nil; queueRunning = false; queuePauseRequested = false
            activeQueueItemID = nil; isBusy = false; isStarting = false
            musicQueue?.peakMemory = peakApplicationMemory
            do { try storeQueue() } catch { errorMessage = "Nie zapisano postępu kolejki: \(error.localizedDescription)" }
            if let value = musicQueue {
                writeQueueReport(value)
                if value.storageVersion == 3, value.completedCount == value.items.count,
                   value.failedCount == 0, safetyStopReason == nil, value.cleanupState == nil {
                    scheduleCleanup(for: value)
                }
            }
            ProcessInfo.processInfo.endActivity(activity)
        }
        do {
            guard let folder = musicQueue?.outputFolder else { return }
            songs = []
            if generationExecutor == nil { try await runBridge(["command": "library"], outputDirectory: URL(fileURLWithPath: folder)) }
            while !queuePauseRequested, let index = musicQueue?.items.firstIndex(where: { $0.state == "waiting" }) {
                try checkDiskBeforeWork(URL(fileURLWithPath: folder))
                guard let item = musicQueue?.items[index] else { break }
                activeQueueItemID = item.id
                musicQueue!.items[index].state = "running"
                musicQueue!.items[index].attempts += 1
                musicQueue!.items[index].error = nil
                try storeQueue() // Do not submit work until its durable identifier has been saved.
                do {
                    let song = try await performGeneration(item.spec, jobID: item.id, outputDirectory: URL(fileURLWithPath: folder))
                    musicQueue!.items[index].result = song
                    musicQueue!.items[index].elapsed = generationElapsed
                    musicQueue!.items[index].state = "completed"
                    try storeQueue()
                } catch {
                    // A committed result remains completed even if saving local queue state failed.
                    if musicQueue!.items[index].state != "completed" {
                        musicQueue!.items[index].state = safetyStopReason == nil ? "failed" : "waiting"
                        musicQueue!.items[index].error = safetyStopReason ?? error.localizedDescription
                        musicQueue!.items[index].elapsed = generationElapsed
                    }
                    try storeQueue()
                    errorMessage = safetyStopReason ?? error.localizedDescription
                    if pauseQueueOnError || safetyStopReason != nil { queuePauseRequested = true }
                }
                activeQueueItemID = nil
            }
            if musicQueue?.waitingCount == 0 {
                status = "Kolekcja zakończona: \(musicQueue?.completedCount ?? 0) gotowych, \(musicQueue?.failedCount ?? 0) błędów."
            } else {
                status = "Kolejka wstrzymana. Możesz ją wznowić od następnej pozycji."
            }
        } catch { errorMessage = error.localizedDescription; status = "Kolejka wstrzymana — sprawdź komunikat." }
    }

    func performGeneration(_ spec: SongRequest, jobID: String? = nil, outputDirectory: URL? = nil) async throws -> Song {
        latestResult = nil; receivedResult = false; errorMessage = nil
        startGenerationClock()
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: "Generowanie utworu muzycznego")
        defer {
            finishGenerationClock()
            ProcessInfo.processInfo.endActivity(activity)
        }
        if let executor = generationExecutor {
            let result = try await executor(spec, jobID, outputDirectory)
            if let reason = safetyStopReason { throw StudioFailure(message: reason) }
            return result
        }
        if let jobID = jobID {
            try await runBridge(["command":"recover_job", "job_id":jobID], outputDirectory: outputDirectory)
            if let recovered = latestResult { return recovered }
        }
        try await ensureEngine()
        status = "Tworzenie: \(spec.title)"
        try await runBridge(spec.payload(jobID: jobID), outputDirectory: outputDirectory)
        guard let result = latestResult else { throw StudioFailure(message: "Silnik nie zwrócił gotowego utworu. Sprawdź logi.") }
        return result
    }
}
