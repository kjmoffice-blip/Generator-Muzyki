import Foundation

extension StudioModel {
    @discardableResult
    func runBridge(_ request: [String: Any], outputDirectory: URL? = nil,
                   deliverEvents: Bool = true) async throws -> [[String: Any]] {
        guard let script = Bundle.main.url(forResource: "bridge", withExtension: "py", subdirectory: "Bridge") else {
            throw StudioFailure(message: "Brakuje modułu połączenia w aplikacji.")
        }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = runtimePython
        process.arguments = ["-u", script.path, "--root", root.path, "--server", engineServer,
                             "--storage-layout", "flat", "--output-dir", (outputDirectory ?? saveDirectory).path]
        process.currentDirectoryURL = root; process.environment = environment()
        process.standardInput = input; process.standardOutput = output
        process.standardError = try logHandle("aplikacja.log")
        let encoded = try JSONSerialization.data(withJSONObject: request)
        guard encoded.count < 5_000_000 else { throw StudioFailure(message: "Lista jest za duża. Podziel ją na mniejsze kolekcje.") }
        try process.run()
        if deliverEvents { bridge = process } else { maintenanceBridge = process }
        input.fileHandleForWriting.write(encoded + Data([10])); try input.fileHandleForWriting.close()
        let model = self
        let result = await Task.detached { () -> (Int32, [Data]) in
            var pending = Data(), events: [Data] = []
            let handle = output.fileHandleForReading
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 10) {
                    let line = pending.prefix(upTo: newline)
                    pending.removeSubrange(...newline)
                    let prefix = Data("ACE_EVENT ".utf8)
                    if line.starts(with: prefix) {
                        let json = Data(line.dropFirst(prefix.count)); events.append(json)
                        if deliverEvents { await model.handleEvent(json) }
                    }
                }
            }
            process.waitUntilExit()
            return (process.terminationStatus, events)
        }.value
        if deliverEvents { bridge = nil } else { maintenanceBridge = nil }
        let events = result.1.compactMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
        if result.0 != 0 {
            let message = events.last(where: { $0["type"] as? String == "error" })?["message"] as? String
            throw StudioFailure(message: message ?? safetyStopReason ?? "Nie udało się wykonać zadania. Sprawdź logi aplikacji.")
        }
        return events
    }
}
