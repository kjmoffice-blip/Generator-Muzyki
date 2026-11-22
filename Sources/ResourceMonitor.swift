import Foundation
import AppKit
import Darwin

@_silgen_name("sos_process_tree_bytes") private func processTreeBytes(_ pid: Int32, _ depth: Int32) -> UInt64
@_silgen_name("sos_available_memory_bytes") private func availableMemoryBytes() -> UInt64

enum DiskCondition: String, Codable { case normal, warning, critical, unavailable }

struct ResourceSnapshot {
    var applicationBytes: UInt64 = 0
    var availableRAM: UInt64 = 0
    var totalRAM: UInt64 = ProcessInfo.processInfo.physicalMemory
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var folder = ""
    var volume = "Dysk zapisu"
    var condition: DiskCondition = .unavailable
    var freeFraction: Double { diskTotal > 0 ? Double(diskFree) / Double(diskTotal) : 0 }
    static func diskCondition(free: Int64, total: Int64) -> DiskCondition {
        guard total > 0, free >= 0 else { return .unavailable }
        let ratio = Double(free) / Double(total)
        return ratio <= 0.01 ? .critical : ratio < 0.05 ? .warning : .normal
    }
    static func measure(folder: URL, includeRAM: Bool = true) -> ResourceSnapshot {
        var value = ResourceSnapshot()
        value.folder = folder.path
        if includeRAM {
            value.applicationBytes = processTreeBytes(getpid(), 0)
            value.availableRAM = min(value.totalRAM, availableMemoryBytes())
        }
        if FileManager.default.fileExists(atPath: folder.path),
           let info = try? FileManager.default.attributesOfFileSystem(forPath: folder.path),
           let free = info[.systemFreeSize] as? NSNumber, let total = info[.systemSize] as? NSNumber {
            value.diskFree = free.int64Value; value.diskTotal = total.int64Value
            value.condition = diskCondition(free: value.diskFree, total: value.diskTotal)
            value.volume = (try? folder.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? "Dysk zapisu"
        }
        return value
    }
    static func ramLabel(_ bytes: UInt64) -> String {
        bytes < 1_073_741_824 ? String(format: "%.0f MB", Double(bytes) / 1_048_576)
            : String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
    var diskLabel: String {
        guard condition != .unavailable else { return "Dysk niedostępny" }
        return String(format: "%.1f GB · %.1f%% wolne", Double(diskFree) / 1_000_000_000, freeFraction * 100)
    }
}

extension StudioModel {
    func startResourceMonitor() {
        updateResources()
        resourceTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateResources() }
        }
    }
    func updateResources() {
        let folder = queueRunning ? musicQueue?.outputFolder.map { URL(fileURLWithPath: $0) } ?? saveDirectory : saveDirectory
        resources = resourceSampler?(folder) ?? ResourceSnapshot.measure(folder: folder)
        peakApplicationMemory = max(peakApplicationMemory, resources.applicationBytes)
        let critical = resources.condition == .critical || resources.condition == .unavailable
        if !critical { lastDiskAlarmFolder = nil; return }
        if resources.condition == .critical, lastDiskAlarmFolder != folder.path {
            lastDiskAlarmFolder = folder.path
            alarmPlayer()
        }
        guard isBusy, safetyStopReason == nil else { return }
        safetyStopReason = resources.condition == .unavailable
            ? "Dysk zapisu jest niedostępny. Podłącz go i wznów kolejkę."
            : "Wstrzymano generowanie: na dysku zapisu pozostał najwyżej 1% wolnego miejsca."
        queuePauseRequested = true
        status = safetyStopReason!; errorMessage = safetyStopReason
        stopOwnedGeneration()
    }
    func checkDiskBeforeWork(_ folder: URL? = nil) throws {
        let current = resourceSampler?(folder ?? saveDirectory) ?? ResourceSnapshot.measure(folder: folder ?? saveDirectory, includeRAM: false)
        guard current.condition != .unavailable else { throw StudioFailure(message: "Dysk zapisu jest niedostępny.") }
        guard current.condition != .critical else {
            throw StudioFailure(message: "Zwolnij miejsce na dysku zapisu. Przy 1% wolnej pojemności generowanie jest wstrzymane.")
        }
    }
    func stopOwnedGeneration() {
        if bridge?.isRunning == true { bridge?.terminate() }
        if let process = engine, process.isRunning {
            let pid = process.processIdentifier
            if pid > 1, getpgid(pid) == pid { kill(-pid, SIGTERM) }
            else { process.terminate() }
        }
    }
}
