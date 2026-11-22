import Foundation

struct Song: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var caption: String
    var lyrics: String
    var duration: Double
    var bpm: Int?
    var language: String
    var seed: Int?
    var audioPath: String
    var createdAt: String
    var format: String
    var jobID: String? = nil
}

struct StudioFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
