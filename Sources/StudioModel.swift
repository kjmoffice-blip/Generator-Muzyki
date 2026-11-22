import Foundation
import AppKit
import AVFoundation

@MainActor final class StudioModel: ObservableObject {
    @Published var title = ""
    @Published var caption = ""
    @Published var lyrics = ""
    @Published var duration: Double = 90
    @Published var bpm: Int = 112
    @Published var language = "pl"
    @Published var instrumental = false
    @Published var thinking = true
    @Published var seed = "-1"
    @Published var steps = 8
    @Published var format = "mp3"
    @Published var bitrate = "192k"
    @Published var outputFolderPath = ""
    @Published var referenceAudio: URL?
    @Published var generationStartedAt: TimeInterval?
    @Published var generationElapsed: TimeInterval = 0
    @Published var songs: [Song] = []
    @Published var isBusy = false
    @Published var isStarting = false
    @Published var status = "Gotowy na Twój pomysł"
    @Published var errorMessage: String?
    @Published var selectedSong: Song?
    @Published var isPlaying = false
    @Published var playbackTime: Double = 0
    @Published var playbackDuration: Double = 0
    let root: URL
    let runtimeRoot: URL
    let defaultOutput: URL
    let preferences: UserDefaults
    @Published var resources = ResourceSnapshot()
    @Published var safetyStopReason: String?
    @Published var cleanupMessage: String?
    @Published var maintenanceBusy = false
    @Published var latestReportURL: URL?
    var resourceTimer: Timer?
    var peakApplicationMemory: UInt64 = 0
    var lastDiskAlarmFolder: String?
    var maintenanceBridge: Process?
    var cleanupTasks: [String: Task<Void, Never>] = [:]
    var resourceSampler: ((URL) -> ResourceSnapshot)?
    var alarmPlayer: () -> Void = { NSSound.beep() }
    @Published var musicQueue: MusicQueue?
    @Published var queueRunning = false
    @Published var queuePauseRequested = false
    @Published var pauseQueueOnError = true
    @Published var importingPlan = false
    @Published var queueStartedAt: Double?
    var importedPlan: MusicQueue?
    var activeQueueItemID: String?
    var latestResult: Song?
    var generationExecutor: ((SongRequest, String?, URL?) async throws -> Song)?
    var engine: Process?
    var enginePort = 0
    var bridge: Process?
    var player: AVAudioPlayer?
    var timer: Timer?
    @Published var loadingLibrary = false
    var receivedResult = false

    init(rootOverride: URL? = nil, preferences: UserDefaults = .standard, restoreQueue: Bool = true,
         runtimeOverride: URL? = nil) {
        self.preferences = preferences
        let preview = Bundle.main.object(forInfoDictionaryKey: "SOSMusicPreviewMode") as? Bool ?? false
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SOS Digital/Generator Muzyki" + (preview ? "/Preview" : ""), isDirectory: true)
        root = rootOverride ?? support
        runtimeRoot = runtimeOverride ?? (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Runtime")
        defaultOutput = rootOverride?.appendingPathComponent("Piosenki")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Generator Muzyki")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: defaultOutput, withIntermediateDirectories: true)
        outputFolderPath = preferences.string(forKey: "musicOutputFolder") ?? ""
        if rootOverride == nil && !preview { migrateLegacyQueues() }
        if restoreQueue { restoreCurrentQueue() }
        if rootOverride == nil { startResourceMonitor(); restorePendingCleanups() }
    }

    func generate() {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        guard !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Opisz, jak ma brzmieć utwór, lub wybierz przykład."; return
        }
        guard instrumental || !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Wpisz tekst piosenki albo włącz utwór instrumentalny."; return
        }
        guard let chosenSeed = Int(seed), chosenSeed >= -1 else {
            errorMessage = "Numer wariantu powinien być liczbą od 0 albo −1 dla losowania."; return
        }
        do { try validateOutputFolder(); try checkDiskBeforeWork() }
        catch { errorMessage = error.localizedDescription; return }
        if let reference = referenceAudio, !FileManager.default.isReadableFile(atPath: reference.path) {
            errorMessage = "Plik wzorcowy jest niedostępny. Wybierz go ponownie."; return
        }
        stopPlayback()
        safetyStopReason = nil
        errorMessage = nil; receivedResult = false; isBusy = true
        let request = SongRequest(title: title.isEmpty ? "Nowy utwór" : title, caption: caption, lyrics: lyrics,
                                  duration: duration, bpm: bpm, language: language, instrumental: instrumental,
                                  thinking: thinking, seed: chosenSeed, steps: steps, format: format, bitrate: bitrate,
                                  referenceAudio: referenceAudio?.path)
        Task {
            do {
                _ = try await performGeneration(request)
            } catch { errorMessage = safetyStopReason ?? error.localizedDescription; status = safetyStopReason ?? "Nie udało się ukończyć utworu" }
            isStarting = false; isBusy = false
            self.writeManualReport(request)
        }
    }

    func refreshLibrary() {
        guard !loadingLibrary, !isBusy, !importingPlan else { return }
        guard FileManager.default.isExecutableFile(atPath: runtimePython.path) else {
            errorMessage = "Instalacja jest niekompletna. Zainstaluj pełną aplikację z silnikiem i modelami."; return
        }
        loadingLibrary = true
        Task {
            do { try await runBridge(["command":"library"]) }
            catch { errorMessage = error.localizedDescription }
            loadingLibrary = false
        }
    }

    func handleEvent(_ data: Data) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = event["type"] as? String else { return }
        if type == "status", let message = event["message"] as? String { status = message }
        if type == "error", let message = event["message"] as? String { errorMessage = message }
        if type == "plan", let object = event["plan"], let raw = try? JSONSerialization.data(withJSONObject: object),
           let decoded = try? JSONDecoder().decode(MusicQueue.self, from: raw) { importedPlan = decoded }
        if type == "library", let list = event["songs"], let raw = try? JSONSerialization.data(withJSONObject: list), let decoded = try? JSONDecoder().decode([Song].self, from: raw) { songs = decoded }
        if type == "result", let object = event["song"], let raw = try? JSONSerialization.data(withJSONObject: object), let song = try? JSONDecoder().decode(Song.self, from: raw) {
            stopPlayback()
            songs.removeAll { $0.id == song.id }; songs.insert(song, at: 0)
            selectedSong = song; playbackDuration = song.duration
            latestResult = song
            receivedResult = true; status = "Gotowe — Twój utwór czeka na odsłuch"
            if let active = activeQueueItemID, let index = musicQueue?.items.firstIndex(where: { $0.id == active }) {
                musicQueue!.items[index].result = song
                musicQueue!.items[index].state = "completed"
                musicQueue!.items[index].elapsed = elapsedGenerationTime()
                do { try storeQueue() } catch { errorMessage = "Nie zapisano stanu kolejki: \(error.localizedDescription)" }
            }
        }
    }

    func openRoot() { NSWorkspace.shared.open(saveDirectory) }
    func openAdvanced() {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        isStarting = true; isBusy = true
        Task {
            do { try await ensureEngine(); NSWorkspace.shared.open(URL(string: engineServer)!); status = "Pełny panel otwarty w przeglądarce" }
            catch { errorMessage = error.localizedDescription }
            isBusy = false; isStarting = false
        }
    }
    func reveal(_ song: Song) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: song.audioPath)]) }
    func reuse(_ song: Song) {
        guard !isBusy else { return }
        title = song.title + " — wariant"; caption = song.caption; lyrics = song.lyrics
        duration = song.duration; bpm = song.bpm ?? 112; language = song.language
        instrumental = song.lyrics.isEmpty || song.lyrics == "[Instrumental]"; seed = "-1"
        status = "Ustawienia wczytane — możesz przygotować nowy wariant"
    }
    func loadExample() {
        guard !isBusy else { return }
        title = "Jeszcze jeden dobry dzień"
        caption = "Pogodny pop-rock, ciepły męski wokal po polsku, gitara akustyczna, melodyjna gitara elektryczna, bas i żywa perkusja. Chwytliwy refren, optymistyczny nastrój poranka, krótkie intro i naturalne zakończenie."
        lyrics = "[Verse 1]\nDeszcz zostawił ślad na szybach\nMiasto budzi cichy świt\nWczoraj tyle nas dzieliło\nDzisiaj łapię z tobą rytm\n\n[Chorus]\nJeszcze jeden dobry dzień\nNiech muzyka niesie mnie\nPodkręć radio, otwórz drzwi\nCały świat zatańczy dziś\n\n[Verse 2]\nZostaw troski na przystanku\nNiech odjadą gdzieś za mgłę\nW ciepłym świetle tego ranka\nWszystko znów zaczyna się\n\n[Chorus]\nJeszcze jeden dobry dzień\nNiech muzyka niesie mnie\nPodkręć radio, otwórz drzwi\nCały świat zatańczy dziś\n\n[Outro]\nJeszcze jeden dobry dzień\nDobrze, że dziś jesteś tu"
        duration = 90; bpm = 112; language = "pl"; instrumental = false
    }
    func shutdown() {
        stopPlayback()
        resourceTimer?.invalidate()
        cleanupTasks.values.forEach { $0.cancel() }
        if maintenanceBridge?.isRunning == true { maintenanceBridge?.terminate() }
        stopOwnedGeneration()
    }
}
