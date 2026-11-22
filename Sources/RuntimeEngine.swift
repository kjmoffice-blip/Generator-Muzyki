import Foundation

@_silgen_name("sos_free_local_port") private func freeLocalPort() -> Int32

extension StudioModel {
    func engineReady() async -> Bool {
        guard engine?.isRunning == true, enginePort > 0 else { return false }
        var request = URLRequest(url: URL(string: engineServer + "/gradio_api/info")!)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let endpoints = json["named_endpoints"] as? [String: Any] else { return false }
        return endpoints["/generation_wrapper"] != nil
    }
    func ensureEngine() async throws {
        if await engineReady() { return }
        guard FileManager.default.isExecutableFile(atPath: runtimePython.path),
              let bootstrap = Bundle.main.url(forResource: "runtime_bootstrap", withExtension: "py", subdirectory: "Bridge") else {
            throw StudioFailure(message: "Brakuje dołączonego silnika. Zainstaluj pełną aplikację.")
        }
        isStarting = true; status = "Uruchamianie studia — wczytuję modele muzyczne…"
        if engine?.isRunning != true {
            enginePort = Int(freeLocalPort())
            guard enginePort > 0 else { throw StudioFailure(message: "Nie można uruchomić lokalnego połączenia z silnikiem.") }
            let process = Process()
            process.executableURL = runtimePython
            process.arguments = ["-u", bootstrap.path, "--server-name", "127.0.0.1", "--port", String(enginePort),
                                 "--config_path", "acestep-v15-turbo", "--lm_model_path", "acestep-5Hz-lm-1.7B",
                                 "--init_service", "true", "--init_llm", "true", "--backend", "mlx", "--batch_size", "1"]
            process.currentDirectoryURL = root; process.environment = environment()
            let log = try logHandle("silnik.log")
            process.standardOutput = log; process.standardError = log; process.standardInput = FileHandle.nullDevice
            try process.run(); engine = process
        }
        for _ in 0..<240 {
            if let reason = safetyStopReason { throw StudioFailure(message: reason) }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if await engineReady() { isStarting = false; status = "Silnik gotowy"; return }
            if engine?.isRunning == false { throw StudioFailure(message: "Silnik nie uruchomił się. Sprawdź raport i logi aplikacji.") }
        }
        throw StudioFailure(message: "Wczytywanie silnika trwa zbyt długo. Sprawdź logi i spróbuj ponownie.")
    }
}
