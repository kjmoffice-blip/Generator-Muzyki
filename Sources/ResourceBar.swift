import SwiftUI

struct ResourceBar: View {
    @ObservedObject var model: StudioModel
    var body: some View {
        HStack(spacing: 0) {
            Text("SOS DIGITAL . PRO").font(.system(size: 10, weight: .semibold)).tracking(1.2)
            Spacer().frame(width: 100)
            metric("RAM APLIKACJI + SILNIKA", value: ResourceSnapshot.ramLabel(model.resources.applicationBytes))
                .help("Pamięć fizyczna aplikacji i jej procesów potomnych. Pamięć współdzielona może być rozliczana w kilku procesach.")
            Spacer().frame(width: 20)
            metric("RAM DOSTĘPNY ≈", value: "\(ResourceSnapshot.ramLabel(model.resources.availableRAM)) / \(ResourceSnapshot.ramLabel(model.resources.totalRAM))")
                .help("Przybliżenie: pamięć wolna i nieaktywna, którą macOS może odzyskać.")
            Spacer().frame(width: 20)
            TimelineView(.animation(minimumInterval: 0.75, paused: model.resources.condition != .warning && model.resources.condition != .critical)) { context in
                metric("DYSK ZAPISU · \(model.resources.volume)", value: model.resources.diskLabel)
                    .foregroundStyle(diskColor(context.date))
            }.help(model.resources.folder)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26).padding(.vertical, 10)
        .background(StudioStyle.sidebar.opacity(0.6))
        .accessibilityElement(children: .contain)
    }
    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .semibold)).lineLimit(1)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).monospacedDigit().lineLimit(1)
        }.frame(minWidth: 160, alignment: .leading)
    }
    private func diskColor(_ date: Date) -> Color {
        if model.resources.condition == .unavailable { return .red }
        if model.resources.condition == .warning || model.resources.condition == .critical {
            return Int(date.timeIntervalSince1970 / 0.75) % 2 == 0 ? .red : .blue
        }
        return Color(red: 0.16, green: 0.31, blue: 0.451)
    }
}
