import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: StudioModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.isBusy == true || model?.maintenanceBusy == true {
            let alert = NSAlert()
            alert.messageText = "Trwa tworzenie muzyki"
            alert.informativeText = "Zakończenie aplikacji przerwie odbieranie utworu. Poczekaj na zakończenie generowania."
            alert.addButton(withTitle: "Wróć do aplikacji")
            alert.runModal()
            return .terminateCancel
        }
        model?.shutdown()
        return .terminateNow
    }
}

@main struct MusicCreatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = StudioModel()
    var body: some Scene {
        Window("Generator Muzyki · SOS Digital", id: "studio") {
            StudioView(model: model)
                .frame(minWidth: 1100, minHeight: 760)
                .preferredColorScheme(.light)
                .onAppear { delegate.model = model; model.refreshLibrary() }
        }
        .defaultSize(width: 1360, height: 900)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("O Generatorze Muzyki") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Generator Muzyki", .applicationVersion: "3.0.0",
                        .credits: NSAttributedString(string: "SOS DIGITAL . PRO\nZaawansowany generator kolekcji muzycznych.\nSilnik: ACE-Step 1.5 • Apple Silicon")])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Utwórz muzykę") { model.generate() }.keyboardShortcut("g").disabled(model.isBusy)
                Button("Wczytaj przykład") { model.loadExample() }.disabled(model.isBusy)
            }
            CommandMenu("Studio") {
                Button("Raport ostatniej generacji", action: model.openLatestReport)
                Button("Wczytaj kolekcję TXT / Word…") { model.choosePlanFile() }.disabled(model.isBusy || model.importingPlan || model.loadingLibrary)
                Button("Instrukcja list utworów") { model.openPlanGuide() }
                Button("Licencje składników") {
                    if let resources = Bundle.main.resourceURL {
                        NSWorkspace.shared.open(resources.appendingPathComponent("Licenses"))
                    }
                }
                Button("Odśwież bibliotekę") { model.refreshLibrary() }.keyboardShortcut("r").disabled(model.isBusy)
                Button("Otwórz folder z muzyką") { model.openRoot() }
                Button("Wybierz folder zapisu…") { model.chooseOutputFolder() }.disabled(model.isBusy || model.loadingLibrary)
                Button("Pełny panel ACE-Step") { model.openAdvanced() }
            }
            CommandGroup(replacing: .help) {
                Button("Instrukcja Generatora Muzyki") {
                    if let url = Bundle.main.url(forResource: "Instrukcja", withExtension: "txt") { NSWorkspace.shared.open(url) }
                }
            }
        }
    }
}
