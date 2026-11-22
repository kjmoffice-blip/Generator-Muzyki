import SwiftUI
import UniformTypeIdentifiers

struct QueueView: View {
    @ObservedObject var model: StudioModel
    @State private var pasteSheet = false
    @State private var pastedText = ""
    @State private var preview: QueueItem?
    @State private var dropTarget = false
    @State private var showReport = false

    private var unavailable: Bool { model.isBusy || model.loadingLibrary || model.importingPlan }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            importBar
            if model.importingPlan { ProgressView("Odczytywanie i sprawdzanie listy…").padding(16) }
            if let queue = model.musicQueue {
                collectionSummary(queue)
                List(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                    queueRow(item, index: index)
                }.listStyle(.plain).scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                controls(queue)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "music.note.list").font(.system(size: 46)).foregroundStyle(.secondary)
                    Text("Jedna lista. Cała kolekcja muzyki.").font(.system(size: 22, weight: .semibold))
                    Text("Wczytaj TXT lub Worda albo wklej przygotowaną listę.\nSprawdź utwory, wybierz folder i uruchom generowanie po kolei.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Wczytaj przykład dwóch utworów", action: model.loadSamplePlan).disabled(unavailable)
                    Button("Instrukcja przygotowania list", action: model.openPlanGuide)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(24)
            .background(dropTarget ? Color.blue.opacity(0.05) : Color.clear)
            .onDrop(of: [UTType.fileURL], isTargeted: $dropTarget) { providers in
                guard !unavailable, let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? item as? URL
                    if let file = url { Task { @MainActor in model.importPlan(file: file) } }
                }
                return true
            }
            .sheet(isPresented: $pasteSheet) { pastePanel }
            .sheet(item: $preview) { item in previewPanel(item) }
            .sheet(isPresented: $showReport) {
                if let queue = model.musicQueue { QueueReportView(model: model, queue: queue) }
            }
    }

    private var importBar: some View {
        HStack(spacing: 12) {
            Button(action: model.choosePlanFile) { Label("Wczytaj TXT / Word", systemImage: "doc.badge.plus") }.disabled(unavailable)
            Button { pasteSheet = true } label: { Label("Wklej listę", systemImage: "doc.on.clipboard") }.disabled(unavailable)
            Menu("Więcej") {
                Button("Przywróć zapisaną kolejkę…", action: model.chooseSavedQueue).disabled(unavailable)
                Button("Przykładowa kolekcja", action: model.loadSamplePlan).disabled(unavailable)
                Button("Instrukcja przygotowania list", action: model.openPlanGuide)
            }
            Spacer()
            Text("TXT · DOCX · do 1000 utworów").font(.system(size: 10)).foregroundStyle(.secondary)
        }.controlSize(.large)
    }

    private func collectionSummary(_ queue: MusicQueue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(queue.title).font(.system(size: 20, weight: .semibold)).lineLimit(2)
                    Text("Gotowe: \(queue.completedCount) z \(queue.items.count)   ·   Oczekuje: \(queue.waitingCount)   ·   Błędy: \(queue.failedCount)")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TimelineView(.animation(minimumInterval: 0.1, paused: model.queueStartedAt == nil)) { _ in
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ŁĄCZNY CZAS KOLEJKI").font(.system(size: 8, weight: .semibold)).tracking(1)
                        Text(StudioModel.generationTimeLabel(model.elapsedQueueTime()))
                            .font(.system(size: 20, weight: .medium, design: .monospaced)).monospacedDigit()
                    }
                }
            }
            ProgressView(value: Double(queue.completedCount), total: Double(max(1, queue.items.count)))
            HStack(alignment: .top) {
                Image(systemName: "folder")
                Text(queue.outputFolder ?? model.saveDirectory.path)
                    .font(.system(size: 10)).textSelection(.enabled).lineLimit(2)
                Spacer()
                if queue.outputFolder == nil {
                    Button("Wybierz folder…", action: model.chooseOutputFolder).disabled(unavailable)
                } else {
                    Text("Folder tej kolekcji jest zapisany.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }.padding(18).background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }

    private func queueRow(_ item: QueueItem, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%03d", index + 1)).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.spec.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text("\(durationLabel(item.spec.duration)) · \(item.spec.bpm == 0 ? "auto" : String(item.spec.bpm)) BPM · \(item.spec.instrumental ? "bez wokalu" : item.spec.language.uppercased()) · \(item.spec.format.uppercased())")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                if let error = item.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2) }
            }
            Spacer(minLength: 10)
            Label(item.statusLabel, systemImage: item.state == "completed" ? "checkmark.circle.fill" : item.state == "failed" ? "exclamationmark.circle.fill" : item.state == "running" ? "waveform" : "clock")
                .font(.system(size: 11)).foregroundStyle(item.state == "completed" ? Color.green : item.state == "failed" ? Color.orange : Color.secondary)
                .frame(width: 92, alignment: .leading)
            if let result = item.result {
                Button { model.play(result) } label: { Image(systemName: "play.fill") }.help("Odtwórz utwór")
                Button { model.reveal(result) } label: { Image(systemName: "folder") }.help("Pokaż plik")
            }
            Button("Podgląd") { preview = item }
            if item.state == "failed" { Button("Ponów") { model.retryQueueItem(item.id) }.disabled(unavailable) }
        }.buttonStyle(.borderless).padding(.vertical, 8)
    }

    private func controls(_ queue: MusicQueue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Raport") { showReport = true }
                Toggle("Wstrzymaj kolejkę przy błędzie", isOn: $model.pauseQueueOnError)
                    .toggleStyle(.checkbox).font(.system(size: 11)).disabled(model.queueRunning)
                Spacer()
                if queue.failedCount > 0 { Button("Ponów błędy") { model.retryQueueItem() }.disabled(unavailable) }
                if model.queueRunning {
                    Button(model.queuePauseRequested ? "Pauza po bieżącym utworze…" : "Pauza po utworze", action: model.requestQueuePause)
                        .disabled(model.queuePauseRequested).controlSize(.large)
                } else {
                    Button(queue.items.contains(where: { $0.attempts > 0 }) ? "Wznów kolejkę" : "Generuj całą kolejkę", action: model.startQueue)
                        .disabled(unavailable || queue.waitingCount == 0).controlSize(.large)
                        .buttonStyle(.borderedProminent)
                }
            }
            Text(model.queueRunning ? model.status : "Postęp zapisuje się automatycznie. Gotowe utwory są pomijane przy wznowieniu.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            if queue.cleanupState == "pending", let deadline = queue.cleanupDeadline {
                HStack {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Komplet gotowy. Porządkowanie plików pomocniczych za \(max(0, Int(ceil(deadline - context.date.timeIntervalSince1970)))) s")
                    }
                    Spacer()
                    Button("Zachowaj pliki pomocnicze", action: model.keepQueueHelpers).disabled(model.maintenanceBusy)
                }.font(.system(size: 10))
            } else if let note = queue.cleanupNote {
                Text(note).font(.system(size: 10)).foregroundStyle(queue.cleanupState == "held" ? .orange : .secondary)
            }
        }
    }

    private var pastePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wklej kolekcję utworów").font(.title2.weight(.semibold))
            Text("Użyj formatu SOS MUSIC PLAN 1 z instrukcji. Każdy utwór ma osobny początek i koniec.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            TextEditor(text: $pastedText).font(.system(size: 12, design: .monospaced))
                .accessibilityLabel("Lista utworów do importu").border(Color.gray.opacity(0.3))
            HStack {
                Button("Instrukcja", action: model.openPlanGuide)
                Spacer()
                Button("Anuluj") { pasteSheet = false }
                Button("Sprawdź i wczytaj") { model.importPlan(text: pastedText); pasteSheet = false }
                    .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 760, height: 580)
    }

    private func previewPanel(_ item: QueueItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.spec.title).font(.title2.weight(.semibold))
            Text("\(durationLabel(item.spec.duration)) · \(item.spec.bpm) BPM · \(item.spec.language.uppercased()) · \(item.spec.instrumental ? "instrumentalny" : item.spec.voice ?? "wokal")")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Brzmienie i styl").font(.headline)
                    Text(item.spec.caption).textSelection(.enabled)
                    Text("Tekst piosenki").font(.headline)
                    Text(item.spec.instrumental ? "[Instrumental]" : item.spec.lyrics).textSelection(.enabled)
                    if let reference = item.spec.referenceAudio { Text("Wzorzec: " + reference).font(.caption).textSelection(.enabled) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("Zamknij") { preview = nil }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 720, height: 570)
    }

    private func durationLabel(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}
