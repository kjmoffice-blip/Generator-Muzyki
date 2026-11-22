import Foundation
import AppKit
import UniformTypeIdentifiers

extension StudioModel {
    var saveDirectory: URL {
        outputFolderPath.isEmpty ? defaultOutput
            : URL(fileURLWithPath: outputFolderPath, isDirectory: true)
    }

    func validateOutputFolder() throws {
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw StudioFailure(message: "Folder danych aplikacji jest niedostępny.")
        }
        if outputFolderPath.isEmpty {
            try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: saveDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue,
              FileManager.default.isWritableFile(atPath: saveDirectory.path) else {
            throw StudioFailure(message: "Folder zapisu jest niedostępny lub nie pozwala na zapis. Podłącz dysk albo wybierz inny folder.")
        }
    }

    func chooseOutputFolder() {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        let panel = NSOpenPanel()
        panel.title = "Folder zapisu utworów"
        panel.message = "Wybierz folder biblioteki. Nowe utwory będą zapisywane w nim automatycznie."
        panel.prompt = "Wybierz folder"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        panel.directoryURL = saveDirectory
        if panel.runModal() == .OK, let url = panel.url { setOutputFolder(url) }
    }

    func setOutputFolder(_ url: URL?) {
        guard !isBusy, !loadingLibrary, !importingPlan else { return }
        stopPlayback(); selectedSong = nil
        outputFolderPath = url?.standardizedFileURL.path ?? ""
        preferences.set(outputFolderPath, forKey: "musicOutputFolder")
        songs = []; errorMessage = nil
        refreshLibrary()
    }

    func chooseReferenceAudio() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = "Wzorzec brzmienia"
        panel.message = "Wybierz utwór jako inspirację dla barwy, miksu i charakteru muzyki."
        panel.prompt = "Wczytaj wzorzec"
        panel.allowedContentTypes = [.mp3, .wav, .aiff, .mpeg4Audio, UTType(filenameExtension: "flac") ?? .audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { setReferenceAudio(url) }
    }

    func setReferenceAudio(_ url: URL) {
        guard !isBusy else { return }
        guard url.isFileURL, ["mp3", "wav", "flac", "m4a", "aif", "aiff"].contains(url.pathExtension.lowercased()),
              FileManager.default.isReadableFile(atPath: url.path) else {
            errorMessage = "Wybierz dostępny plik MP3, WAV, FLAC, M4A lub AIFF."; return
        }
        referenceAudio = url.standardizedFileURL; errorMessage = nil
    }

    func startGenerationClock(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        generationElapsed = 0; generationStartedAt = now
    }

    func elapsedGenerationTime(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> TimeInterval {
        generationStartedAt.map { max(0, now - $0) } ?? generationElapsed
    }

    func finishGenerationClock(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        generationElapsed = elapsedGenerationTime(now: now); generationStartedAt = nil
    }

    static func generationTimeLabel(_ value: TimeInterval) -> String {
        let tenths = Int(max(0, value.isFinite ? value : 0) * 10)
        return String(format: "%02d:%02d:%02d.%d", tenths / 36000, (tenths / 600) % 60, (tenths / 10) % 60, tenths % 10)
    }

    func toggleFullScreen() { NSApplication.shared.keyWindow?.toggleFullScreen(nil) }
}
