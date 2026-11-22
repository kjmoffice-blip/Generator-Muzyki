import Foundation

struct SongRequest: Codable, Equatable {
    var title = ""
    var caption = ""
    var lyrics = ""
    var duration: Double = 90
    var bpm = 112
    var language = "pl"
    var instrumental = false
    var thinking = true
    var seed = -1
    var steps = 8
    var format = "mp3"
    var bitrate = "192k"
    var referenceAudio: String?
    var voice: String?
    enum CodingKeys: String, CodingKey {
        case title, caption, lyrics, duration, bpm, language, instrumental, thinking, seed, steps, format, bitrate, voice
        case referenceAudio = "reference_audio"
    }
    func payload(jobID: String? = nil) throws -> [String: Any] {
        var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as! [String: Any]
        values["command"] = "generate"
        if let jobID = jobID { values["job_id"] = jobID }
        return values
    }
}

struct QueueItem: Identifiable, Codable {
    var id: String
    var spec: SongRequest
    var state: String
    var attempts: Int
    var result: Song?
    var error: String?
    var elapsed: Double?
    var statusLabel: String {
        switch state {
        case "running": return "Powstaje"
        case "completed": return "Gotowy"
        case "failed": return "Błąd"
        default: return "Oczekuje"
        }
    }
}

struct MusicQueue: Identifiable, Codable {
    var id: String
    var title: String
    var items: [QueueItem]
    var kind: String? = "sos-music-queue"
    var version: Int? = 1
    var outputFolder: String?
    var elapsed: Double?
    var storageVersion: Int?
    var cleanupDeadline: Double?
    var cleanupState: String?
    var cleanupNote: String?
    var peakMemory: UInt64?
    var completedCount: Int { items.filter { $0.state == "completed" }.count }
    var failedCount: Int { items.filter { $0.state == "failed" }.count }
    var waitingCount: Int { items.filter { $0.state == "waiting" }.count }
}
