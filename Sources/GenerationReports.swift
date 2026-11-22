import Foundation
import AppKit
import UniformTypeIdentifiers

extension StudioModel {
    var reportDirectory: URL { root.appendingPathComponent("Raporty") }
    func writeQueueReport(_ queue: MusicQueue) {
        do {
            try FileManager.default.createDirectory(at: reportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(queue).write(to: reportDirectory.appendingPathComponent(queue.id + ".json"), options: .atomic)
            let rows = queue.items.map { item in
                "<tr><td>\(escapeHTML(item.spec.title))</td><td>\(item.statusLabel)</td><td>\(Self.generationTimeLabel(item.elapsed ?? 0))</td><td>\(escapeHTML(item.result?.audioPath ?? item.error ?? ""))</td></tr>"
            }.joined()
            let html = reportHTML(title: queue.title, summary: "Gotowe: \(queue.completedCount) z \(queue.items.count), błędy: \(queue.failedCount). Czas: \(Self.generationTimeLabel(queue.elapsed ?? 0)).", rows: rows,
                                  note: queue.cleanupNote ?? "\(queue.cleanupState == "pending" ? "Porządkowanie plików pomocniczych zaplanowane po 30 sekundach." : "Pliki pomocnicze zachowane.")")
            let path = reportDirectory.appendingPathComponent(queue.id + ".html")
            try Data(html.utf8).write(to: path, options: .atomic); latestReportURL = path
        } catch { cleanupMessage = "Nie zapisano raportu: \(error.localizedDescription)" }
    }
    func writeManualReport(_ spec: SongRequest) {
        let item = QueueItem(id: latestResult?.jobID ?? UUID().uuidString, spec: spec,
                             state: receivedResult ? "completed" : "failed", attempts: 1,
                             result: latestResult, error: errorMessage, elapsed: generationElapsed)
        let report = MusicQueue(id: UUID().uuidString, title: spec.title, items: [item],
                                outputFolder: saveDirectory.path, elapsed: generationElapsed, storageVersion: 3,
                                peakMemory: peakApplicationMemory)
        writeQueueReport(report)
        if receivedResult, safetyStopReason == nil, errorMessage == nil, let song = latestResult {
            scheduleManualCleanup(song)
        }
    }
    func exportQueueReport(_ queue: MusicQueue) {
        writeQueueReport(queue)
        let source = reportDirectory.appendingPathComponent(queue.id + ".html")
        guard let data = try? Data(contentsOf: source) else { return }
        let panel = NSSavePanel(); panel.title = "Zapisz raport generacji"
        panel.allowedContentTypes = [.html]; panel.nameFieldStringValue = "Raport generacji.html"
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: .atomic) }
            catch { errorMessage = "Nie zapisano raportu: \(error.localizedDescription)" }
        }
    }
    func openLatestReport() {
        if let url = latestReportURL { NSWorkspace.shared.open(url) }
        else if let queue = musicQueue { writeQueueReport(queue); if let url = latestReportURL { NSWorkspace.shared.open(url) } }
    }
    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    private func reportHTML(title: String, summary: String, rows: String, note: String) -> String {
        """
        <!doctype html><html lang="pl"><meta charset="utf-8"><title>Raport generacji</title>
        <style>body{font:16px -apple-system,sans-serif;background:#edf4f9;color:#294f73;padding:40px;line-height:1.5}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;text-align:left;border-bottom:1px solid #cedbe5;overflow-wrap:anywhere}h1{font-size:26px}</style>
        <h1>\(escapeHTML(title))</h1><p>SOS DIGITAL · GENERATOR MUZYKI</p><p>\(escapeHTML(summary))</p>
        <table><tr><th>Utwór</th><th>Wynik</th><th>Czas generacji</th><th>Plik / komunikat</th></tr>\(rows)</table>
        <p>\(escapeHTML(note))</p></html>
        """
    }
}
