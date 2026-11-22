import Foundation

struct CleanupTicket: Codable {
    var id: String
    var label: String
    var folder: String
    var jobIDs: [String]
    var deadline: Double
    var state: String = "pending"
    var queueID: String?
    var note: String?
}

extension StudioModel {
    var cleanupDirectory: URL { root.appendingPathComponent("Porzadkowanie") }
    func storeCleanup(_ ticket: CleanupTicket) throws {
        guard UUID(uuidString: ticket.id) != nil else { throw StudioFailure(message: "Nieprawidłowe zadanie porządkowania.") }
        try FileManager.default.createDirectory(at: cleanupDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(ticket).write(to: cleanupDirectory.appendingPathComponent(ticket.id + ".json"), options: .atomic)
        guard let queueID = ticket.queueID else { return }
        let path = queueDirectory.appendingPathComponent(queueID + ".json")
        guard var value = try? JSONDecoder().decode(MusicQueue.self, from: Data(contentsOf: path)) else { return }
        value.cleanupDeadline = ticket.deadline; value.cleanupState = ticket.state; value.cleanupNote = ticket.note
        if musicQueue?.id == queueID { musicQueue = value; try storeQueue() }
        else { try JSONEncoder().encode(value).write(to: path, options: .atomic) }
        writeQueueReport(value)
    }
    func scheduleCleanup(for queue: MusicQueue) {
        guard let folder = queue.outputFolder, queue.completedCount == queue.items.count,
              queue.failedCount == 0, queue.items.allSatisfy({ $0.result?.jobID == $0.id }) else { return }
        let ticket = CleanupTicket(id: queue.id, label: queue.title, folder: folder,
                                   jobIDs: queue.items.map(\.id), deadline: Date().timeIntervalSince1970 + 30, queueID: queue.id)
        do { try storeCleanup(ticket); launchCleanup(ticket) }
        catch { cleanupMessage = "Nie zaplanowano porządkowania: \(error.localizedDescription)" }
    }
    func scheduleManualCleanup(_ song: Song) {
        guard let id = song.jobID else { return }
        let ticket = CleanupTicket(id: UUID().uuidString, label: song.title,
                                   folder: URL(fileURLWithPath: song.audioPath).deletingLastPathComponent().path,
                                   jobIDs: [id], deadline: Date().timeIntervalSince1970 + 30)
        do { try storeCleanup(ticket); launchCleanup(ticket) }
        catch { cleanupMessage = "Nie zaplanowano porządkowania: \(error.localizedDescription)" }
    }
    func restorePendingCleanups() {
        let files = (try? FileManager.default.contentsOfDirectory(at: cleanupDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            if let ticket = try? JSONDecoder().decode(CleanupTicket.self, from: Data(contentsOf: file)),
               ticket.state == "pending", UUID(uuidString: ticket.id) != nil { launchCleanup(ticket) }
        }
    }
    func launchCleanup(_ original: CleanupTicket) {
        guard cleanupTasks[original.id] == nil else { return }
        cleanupTasks[original.id] = Task { [weak self] in
            guard let self = self else { return }
            defer { self.cleanupTasks[original.id] = nil }
            var ticket = original
            do {
                while Date().timeIntervalSince1970 < ticket.deadline {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                while self.maintenanceBusy { try await Task.sleep(nanoseconds: 250_000_000) }
                try Task.checkCancellation()
                self.maintenanceBusy = true
                defer { self.maintenanceBusy = false }
                let events = try await self.runBridge(["command":"cleanup_collection", "job_ids":ticket.jobIDs],
                                                     outputDirectory: URL(fileURLWithPath: ticket.folder), deliverEvents: false)
                guard let result = events.last(where: { $0["type"] as? String == "cleanup" })?["result"] as? [String: Any],
                      result["state"] as? String == "completed" else {
                    throw StudioFailure(message: "Nie potwierdzono porządkowania.")
                }
                ticket.state = "completed"; ticket.note = "Usunięto pliki pomocnicze. Nagrania i dane wznowienia zachowano."
                self.cleanupMessage = "Porządkowanie zakończone: \(ticket.label)"
                try self.storeCleanup(ticket)
            } catch is CancellationError { return }
            catch {
                ticket.state = "held"; ticket.note = "Zachowano pliki pomocnicze: \(error.localizedDescription)"
                self.cleanupMessage = ticket.note
                try? self.storeCleanup(ticket)
            }
        }
    }
    func keepQueueHelpers() {
        guard let id = musicQueue?.id else { return }
        let file = cleanupDirectory.appendingPathComponent(id + ".json")
        guard var ticket = try? JSONDecoder().decode(CleanupTicket.self, from: Data(contentsOf: file)),
              ticket.state == "pending", !maintenanceBusy else { return }
        cleanupTasks[id]?.cancel(); cleanupTasks[id] = nil
        ticket.state = "cancelled"; ticket.note = "Pliki pomocnicze zachowane na życzenie użytkownika."
        try? storeCleanup(ticket)
    }
}
