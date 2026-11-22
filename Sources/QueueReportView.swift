import SwiftUI

struct QueueReportView: View {
    @ObservedObject var model: StudioModel
    let queue: MusicQueue
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Raport generacji").font(.title2.weight(.semibold))
            Text(queue.title).font(.headline)
            Text("Gotowe: \(queue.completedCount) / \(queue.items.count) · Błędy: \(queue.failedCount) · Czas: \(StudioModel.generationTimeLabel(queue.elapsed ?? 0))")
                .font(.system(size: 12))
            if let memory = queue.peakMemory {
                Text("Najwyższy odczyt RAM aplikacji i silnika: \(ResourceSnapshot.ramLabel(memory))")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(queue.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.spec.title).font(.system(size: 13, weight: .semibold))
                            Text("\(item.statusLabel) · generacja \(StudioModel.generationTimeLabel(item.elapsed ?? 0)) · podejścia: \(item.attempts)")
                                .font(.system(size: 11))
                            if let result = item.result { Text(result.audioPath).font(.system(size: 10)).textSelection(.enabled) }
                            if let error = item.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
                        }
                        Divider()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let note = queue.cleanupNote { Text(note).font(.system(size: 11)) }
            HStack {
                Button("Zapisz raport…") { model.exportQueueReport(queue) }
                Spacer()
                Button("Zamknij") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 760, height: 580)
    }
}
