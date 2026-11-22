import Foundation

extension StudioModel {
    var engineDirectory: URL { runtimeRoot.appendingPathComponent("Silnik") }
    var runtimePython: URL { runtimeRoot.appendingPathComponent("Runtime/python/bin/python3.12") }
    var engineServer: String { "http://127.0.0.1:\(enginePort > 0 ? enginePort : 7862)" }
    func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for key in ["PYTHONHOME", "PYTHONSTARTUP", "PYTHONUSERBASE", "DYLD_LIBRARY_PATH", "DYLD_INSERT_LIBRARIES"] {
            env.removeValue(forKey: key)
        }
        env["PATH"] = runtimeRoot.appendingPathComponent("Tools").path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        env["PYTHONPATH"] = engineDirectory.path + ":" + engineDirectory.appendingPathComponent(".venv/lib/python3.12/site-packages").path
        env["PYTHONNOUSERSITE"] = "1"
        env["PYTHONUNBUFFERED"] = "1"; env["PYTHONDONTWRITEBYTECODE"] = "1"
        env["TOKENIZERS_PARALLELISM"] = "false"; env["ACESTEP_LM_BACKEND"] = "mlx"
        env["HF_HUB_OFFLINE"] = "1"; env["TRANSFORMERS_OFFLINE"] = "1"
        env["GRADIO_ANALYTICS_ENABLED"] = "False"
        for (key, child) in ["HF_HOME":"Cache/huggingface", "HF_MODULES_CACHE":"Cache/hf-modules",
                             "GRADIO_TEMP_DIR":"Cache/gradio", "MPLCONFIGDIR":"Cache/matplotlib",
                             "NUMBA_CACHE_DIR":"Cache/numba", "XDG_CACHE_HOME":"Cache", "TORCH_HOME":"Cache/torch",
                             "SOS_MUSIC_ENGINE_OUTPUT":"Cache/gradio_outputs", "TMPDIR":"Temp"] {
            let folder = root.appendingPathComponent(child)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            env[key] = folder.path
        }
        env["SOS_MUSIC_DATA_DIR"] = root.path
        env["SOS_MUSIC_FFMPEG"] = runtimeRoot.appendingPathComponent("Tools/ffmpeg").path
        env["SOS_MUSIC_FFPROBE"] = runtimeRoot.appendingPathComponent("Tools/ffprobe").path
        return env
    }
    func logHandle(_ name: String) throws -> FileHandle {
        let dir = root.appendingPathComponent("Logi")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: file.path) { FileManager.default.createFile(atPath: file.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: file); try handle.seekToEnd()
        return handle
    }
    func migrateLegacyQueues() {
        let source = URL(fileURLWithPath: "/Volumes/500GBSSDKJM/ACE/Kolejki")
        guard !FileManager.default.fileExists(atPath: queueDirectory.path),
              FileManager.default.fileExists(atPath: source.path) else { return }
        do { try FileManager.default.copyItem(at: source, to: queueDirectory) }
        catch { errorMessage = "Nie skopiowano poprzednich kolejek: \(error.localizedDescription)" }
    }
}
