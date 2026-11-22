import SwiftUI
import UniformTypeIdentifiers

enum StudioStyle {
    static let background = Color(red: 0.925, green: 0.950, blue: 0.969)
    static let sidebar = Color(red: 0.835, green: 0.893, blue: 0.940)
    static let surface = Color(red: 0.985, green: 0.992, blue: 0.998)
    static let input = Color(red: 0.899, green: 0.936, blue: 0.963)
    static let line = Color(red: 0.690, green: 0.761, blue: 0.820).opacity(0.65)
    static let secondary = Color(red: 0.350, green: 0.438, blue: 0.516)
    static let amber = Color(red: 0.160, green: 0.375, blue: 0.565)
}

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @State private var page = "queue"
    @State private var search = ""
    @State private var advanced = false
    @State private var referenceDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            ResourceBar(model: model)
            Divider()
            HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                if page == "create" { creationWorkspace } else if page == "queue" { QueueView(model: model) } else { libraryWorkspace }
                if let message = model.errorMessage { errorBanner(message) }
                if model.selectedSong != nil { player }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
        .background(LinearGradient(colors: [StudioStyle.background, Color(red: 0.82, green: 0.89, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(Color(red: 0.160, green: 0.310, blue: 0.451))
        .tint(StudioStyle.amber)
        .preferredColorScheme(.light)
        .onAppear { model.refreshLibrary() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "waveform")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Color(red: 0.68, green: 0.45, blue: 0.12))
                    .frame(width: 40, height: 44)
                    .background(StudioStyle.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generator").font(.system(size: 17, weight: .semibold))
                    Text("Muzyki").font(.system(size: 17, weight: .semibold))
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 38)
            Text("SOS DIGITAL . PRO")
                .font(.system(size: 9.5, weight: .semibold)).tracking(1.1)
                .lineLimit(1)
                .foregroundStyle(StudioStyle.secondary)
                .padding(.horizontal, 10).padding(.bottom, 12)
            navigationButton("Nowy utwór", symbol: "square.and.pencil", value: "create")
            navigationButton("Kolekcja", symbol: "list.number", value: "queue")
            navigationButton("Biblioteka", symbol: "music.note.list", value: "library")
            Spacer()
            VStack(alignment: .leading, spacing: 13) {
                Button(action: model.openRoot) { Label("Folder z muzyką", systemImage: "folder") }
                Button(action: model.openAdvanced) { Label("Pełny panel ACE", systemImage: "slider.horizontal.3") }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(StudioStyle.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 25)
            Rectangle().fill(StudioStyle.line).frame(height: 1)
            HStack(spacing: 7) {
                Circle().fill(model.isStarting ? StudioStyle.amber : Color.green.opacity(0.8))
                    .frame(width: 6, height: 6)
                Text("Lokalnie na Twoim Macu")
                    .font(.system(size: 10))
                    .foregroundStyle(StudioStyle.secondary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 9)
        }
        .padding(.horizontal, 16)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(LinearGradient(colors: [StudioStyle.sidebar, Color(red: 0.92, green: 0.95, blue: 0.97)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .trailing) { Rectangle().fill(StudioStyle.line).frame(width: 1) }
    }

    private func navigationButton(_ name: String, symbol: String, value: String) -> some View {
        Button {
            page = value
            if value == "library" { model.refreshLibrary() }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol).frame(width: 18)
                Text(name).fontWeight(page == value ? .semibold : .regular)
                    .lineLimit(1).layoutPriority(1)
                Spacer()
                if value == "library" { Text("\(model.songs.count)").font(.system(size: 11)).opacity(0.65) }
            }
            .font(.system(size: 13))
            .foregroundStyle(page == value ? StudioStyle.amber : StudioStyle.secondary)
            .padding(.horizontal, 12).padding(.vertical, 13)
            .background(page == value ? StudioStyle.amber.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 5)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(page == "create" ? "Z pomysłu w muzykę." : page == "queue" ? "Cała kolekcja. Jeden start." : "Twoja biblioteka.")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                Text(page == "create" ? "Napisz tekst, wybierz brzmienie i stwórz swój utwór." : page == "queue" ? "Wczytaj listę, sprawdź ustawienia i generuj po kolei." : "Wszystkie zapisane utwory, gotowe do odsłuchu.")
                    .font(.system(size: 12)).foregroundStyle(StudioStyle.secondary)
            }
            Spacer(minLength: 16)
            generationClock
            if page == "create" {
                Button(action: model.loadExample) { Label("Wczytaj przykład", systemImage: "sparkles") }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(StudioStyle.amber)
                    .disabled(model.isBusy)
            } else if page == "library" {
                Button(action: model.refreshLibrary) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("Odśwież bibliotekę")
            }
            Button(action: model.toggleFullScreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 34)
                    .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(StudioStyle.line))
            }.buttonStyle(.plain).help("Przełącz pełny ekran").accessibilityLabel("Pełny ekran")
        }
        .padding(.horizontal, 28).padding(.vertical, 23)
        .overlay(alignment: .bottom) { Rectangle().fill(StudioStyle.line).frame(height: 1) }
    }

    private var generationClock: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: model.generationStartedAt == nil)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle().fill(model.generationStartedAt == nil ? Color.gray : Color.orange).frame(width: 5, height: 5)
                    Text("CZAS GENERACJI").font(.system(size: 8, weight: .medium)).tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Text(StudioModel.generationTimeLabel(model.elapsedGenerationTime()))
                    .font(.system(size: 22, weight: .medium, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.32))
                    .accessibilityLabel("Czas generacji")
                    .accessibilityValue(StudioModel.generationTimeLabel(model.elapsedGenerationTime()))
            }.padding(.horizontal, 13).padding(.vertical, 9)
                .background(Color(red: 0.10, green: 0.15, blue: 0.19), in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var referencePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("WZORZEC BRZMIENIA")
                Spacer()
                Text("opcjonalnie").font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.plus").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.referenceAudio?.lastPathComponent ?? "Przeciągnij MP3 lub wybierz plik")
                        .font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    Text("Inspiracja dla barwy, miksu i charakteru muzyki.")
                        .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                }
                Spacer(minLength: 4)
                Button("Wczytaj MP3…", action: model.chooseReferenceAudio).font(.system(size: 11))
                if model.referenceAudio != nil {
                    Button { model.referenceAudio = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).help("Usuń wzorzec").accessibilityLabel("Usuń wzorzec")
                }
            }.padding(14)
                .background(referenceDropTarget ? StudioStyle.input : StudioStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioStyle.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .onDrop(of: [UTType.fileURL], isTargeted: $referenceDropTarget) { providers in
                    guard !model.isBusy, let provider = providers.first else { return false }
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url: URL?
                        if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                        else if let value = item as? URL { url = value }
                        else { url = nil }
                        if let file = url { Task { @MainActor in model.setReferenceAudio(file) } }
                    }
                    return true
                }
        }
    }

    private var creationWorkspace: some View {
        VStack(spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 22) {
                    songEditor.frame(maxWidth: .infinity)
                    settingsPanel.frame(width: 250)
                }
                .padding(28)
            }
            generationBar
        }
    }

    private var songEditor: some View {
        VStack(alignment: .leading, spacing: 21) {
            VStack(alignment: .leading, spacing: 9) {
                sectionLabel("TYTUŁ UTWORU")
                TextField("Nadaj swojej piosence tytuł", text: $model.title)
                    .font(.system(size: 19, weight: .medium))
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Tytuł utworu")
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack { sectionLabel("BRZMIENIE I STYL"); Spacer(); Text("gatunek · instrumenty · nastrój").font(.system(size: 10)).foregroundStyle(StudioStyle.secondary) }
                StudioTextEditor(text: $model.caption,
                    placeholder: "Np. pogodny pop-rock, ciepły męski wokal, gitara akustyczna i żywa perkusja…",
                    label: "Brzmienie i styl", height: 95)
                HStack(spacing: 7) {
                    styleChip("Pop", caption: "Uplifting modern pop, warm clear lead vocal, bright piano, rhythmic guitar, tight drums, catchy melodic chorus, polished studio production.")
                    styleChip("Rock", caption: "Melodic pop-rock, expressive warm male lead vocal, acoustic rhythm guitar, electric guitar fills, live drums and warm bass, anthemic catchy chorus.")
                    styleChip("Elektronika", caption: "Melodic electronic pop, warm synth pads, deep bass, crisp dance drums, atmospheric vocal, uplifting memorable chorus, detailed clean production.")
                    styleChip("Spokojnie", caption: "Intimate acoustic ballad, gentle expressive vocal, fingerpicked acoustic guitar, soft piano and subtle strings, warm natural recording, emotional melody.")
                }
                HStack(spacing: 7) {
                    styleChip("Mocna klubowa", caption: "Powerful club dance and electro house, bass boosted deep sub bass, punchy four-on-the-floor kick, pumping sidechain bass, bright synth hook, energetic build and massive bass drop, catchy vocal chorus, clean controlled low end.", bpm: 128)
                    styleChip("Techno", caption: "Driving peak-time techno, powerful rumbling sub bass, pounding four-on-the-floor kick, hypnotic synth sequences, crisp industrial percussion, dark club atmosphere, tension builds and explosive drops, clean bass-heavy production.", bpm: 140)
                    styleChip("Trance", caption: "Uplifting melodic trance, soaring supersaw leads, sparkling arpeggios, deep rolling bass, driving club kick, emotional vocal hook, atmospheric breakdown and euphoric melodic drop, wide polished mix.", bpm: 138)
                    styleChip("Latino", caption: "Sunny Latin dance, bouncy dembow groove, warm syncopated bass, Latin percussion, rhythmic guitar, bright brass and tropical synths, expressive lead vocal and catchy joyful chorus.", bpm: 108)
                    styleChip("Skoli", caption: "Polish latino dance, bouncy tropical dance beat, deep warm bass, rhythmic Latin guitar, bright synth hooks, warm confident male lead singing clearly in Polish, flirtatious joyful mood, very catchy simple singalong chorus, polished dance production.", bpm: 105)
                }
            }
            referencePanel
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    sectionLabel("TEKST PIOSENKI")
                    Spacer()
                    Text(model.instrumental ? "Tryb instrumentalny" : "[Verse] zwrotka · [Chorus] refren")
                        .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                }
                StudioTextEditor(text: $model.lyrics,
                    placeholder: "[Verse]\nTutaj zaczyna się Twoja historia…\n\n[Chorus]\nA tutaj refren, który zostaje w głowie.",
                    label: "Tekst piosenki", height: 255)
                    .opacity(model.instrumental ? 0.4 : 1)
                    .disabled(model.instrumental)
            }
        }
        .disabled(model.isBusy)
    }

    private func styleChip(_ title: String, caption: String, bpm: Int? = nil) -> some View {
        Button { model.caption = caption; if let tempo = bpm { model.bpm = tempo } } label: {
            Text(title).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(StudioStyle.surface, in: Capsule())
                .overlay(Capsule().stroke(StudioStyle.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 23) {
            VStack(alignment: .leading, spacing: 17) {
                Label("Ustawienia utworu", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Długość").foregroundStyle(StudioStyle.secondary)
                        Spacer()
                        Text(timeLabel(model.duration)).fontWeight(.semibold).monospacedDigit()
                    }.font(.system(size: 12))
                    Slider(value: $model.duration, in: 10...300, step: 10)
                        .accessibilityLabel("Długość utworu w sekundach")
                    HStack(spacing: 7) {
                        durationChoice(30); durationChoice(60); durationChoice(90); durationChoice(180)
                    }
                }
                separator
                HStack {
                    Text("Tempo").font(.system(size: 12)).foregroundStyle(StudioStyle.secondary)
                    Spacer()
                    TextField("112", value: $model.bpm, format: .number)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                        .frame(width: 42).accessibilityLabel("Tempo BPM")
                    Text("BPM").font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                    Stepper("Tempo", value: $model.bpm, in: 40...240, step: 1).labelsHidden()
                }
                separator
                VStack(alignment: .leading, spacing: 9) {
                    Text("Język wokalu").font(.system(size: 12)).foregroundStyle(StudioStyle.secondary)
                    Picker("Język wokalu", selection: $model.language) {
                        Text("Polski").tag("pl")
                        Text("Angielski").tag("en")
                        Text("Niemiecki").tag("de")
                        Text("Hiszpański").tag("es")
                        Text("Francuski").tag("fr")
                        Text("Włoski").tag("it")
                    }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity)
                }
                separator
                Toggle(isOn: $model.instrumental) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bez wokalu").font(.system(size: 12, weight: .medium))
                        Text("Utwór instrumentalny").font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                    }
                }.toggleStyle(.switch).controlSize(.small)
                Toggle(isOn: $model.thinking) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Planowanie kompozycji").font(.system(size: 12, weight: .medium))
                        Text("Spójna struktura utworu").font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.toggleStyle(.switch).controlSize(.small)
            }
            .padding(18)
            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 13))

            DisclosureGroup(isExpanded: $advanced) {
                advancedSettings.padding(.top, 15)
            } label: {
                Text("Zaawansowane").font(.system(size: 12, weight: .medium))
            }
            .padding(16)
            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                Label("Folder zapisu", systemImage: "folder").font(.system(size: 12, weight: .semibold))
                Text(model.saveDirectory.path).font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                    .lineLimit(3).truncationMode(.middle).textSelection(.enabled).help(model.saveDirectory.path)
                Button("Wybierz folder…", action: model.chooseOutputFolder)
                    .font(.system(size: 11)).disabled(model.loadingLibrary)
                if !model.outputFolderPath.isEmpty {
                    Button("Folder domyślny") { model.setOutputFolder(nil) }
                        .font(.system(size: 10)).disabled(model.loadingLibrary)
                }
                Text("Biblioteka pokazuje utwory z wybranego folderu.")
                    .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(model.isBusy)
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Format").font(.system(size: 12))
                Spacer()
                Picker("Format", selection: $model.format) {
                    Text("MP3").tag("mp3"); Text("WAV").tag("wav"); Text("FLAC").tag("flac")
                }.labelsHidden().frame(width: 110)
            }
            if model.format == "mp3" {
                Picker("Jakość MP3", selection: $model.bitrate) {
                    Text("128 kb/s").tag("128k")
                    Text("192 kb/s").tag("192k")
                    Text("320 kb/s").tag("320k")
                }.font(.system(size: 12))
            }
            Stepper(value: $model.steps, in: 1...20) {
                Text("Kroki: \(model.steps)").font(.system(size: 12))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Ziarno losowania").font(.system(size: 12))
                TextField("−1 = losowo", text: $model.seed)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Ziarno losowania")
                Text("−1 tworzy nowy wariant za każdym razem.")
                    .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
            }
        }
    }

    private func durationChoice(_ duration: Double) -> some View {
        Button { model.duration = duration } label: {
            Text(timeLabel(duration)).font(.system(size: 10, weight: .medium)).monospacedDigit()
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .foregroundStyle(model.duration == duration ? StudioStyle.amber : StudioStyle.secondary)
                .background(model.duration == duration ? StudioStyle.amber.opacity(0.12) : StudioStyle.input,
                            in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain)
    }

    private var generationBar: some View {
        HStack(spacing: 18) {
            if model.isBusy || model.isStarting {
                ProgressView().controlSize(.small).frame(width: 20)
            } else {
                Image(systemName: "waveform").font(.system(size: 19)).foregroundStyle(StudioStyle.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.status).font(.system(size: 12, weight: .medium)).lineLimit(2)
                if model.isBusy {
                    Text("Możesz w tym czasie przeglądać bibliotekę.")
                        .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                } else {
                    Text("\(timeLabel(model.duration)) · \(model.bpm) BPM · \(model.instrumental ? "instrumental" : "wokal")")
                        .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(action: model.generate) {
                HStack(spacing: 9) {
                    Image(systemName: model.isBusy ? "waveform" : "sparkles")
                    Text(model.isBusy ? "Powstaje Twój utwór…" : "Utwórz muzykę")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(minWidth: 205).padding(.vertical, 15)
                .background(StudioStyle.amber, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(model.isBusy || model.importingPlan || model.loadingLibrary || model.isStarting || model.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(model.isBusy || model.isStarting ? 0.55 : 1)
        }
        .padding(.horizontal, 28).padding(.vertical, 18)
        .background(StudioStyle.sidebar.opacity(0.6))
        .overlay(alignment: .top) { separator }
    }

    private var libraryWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(StudioStyle.secondary)
                TextField("Szukaj utworu…", text: $search).textFieldStyle(.plain)
                    .accessibilityLabel("Szukaj utworu")
                Spacer()
                Text("Utwory: \(model.songs.count)").font(.system(size: 11)).foregroundStyle(StudioStyle.secondary)
            }
            .padding(13).background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 9))
            if filteredSongs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "music.note").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(StudioStyle.amber)
                    Text(search.isEmpty ? "Tu zacznie się Twoja kolekcja." : "Nie ma takiego utworu.")
                        .font(.system(size: 20, weight: .medium))
                    Text(search.isEmpty ? "Stwórz pierwszą piosenkę. Zapiszemy ją tutaj automatycznie." : "Spróbuj wpisać inny tytuł.")
                        .font(.system(size: 12)).foregroundStyle(StudioStyle.secondary)
                    if search.isEmpty {
                        Button("Utwórz pierwszy utwór") { page = "create" }.tint(StudioStyle.amber)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredSongs) { song in songRow(song) }
                    }
                }
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var filteredSongs: [Song] {
        model.songs.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 16) {
            Button { model.play(song) } label: {
                Image(systemName: model.selectedSong?.id == song.id && model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16)).foregroundStyle(StudioStyle.amber)
                    .frame(width: 47, height: 47)
                    .background(StudioStyle.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).help("Odtwórz lub wstrzymaj")
            VStack(alignment: .leading, spacing: 6) {
                Text(song.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text(song.caption).font(.system(size: 11)).foregroundStyle(StudioStyle.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(timeLabel(song.duration)).font(.system(size: 12)).monospacedDigit().foregroundStyle(StudioStyle.secondary)
            Text(song.format.uppercased()).font(.system(size: 10, weight: .medium)).foregroundStyle(StudioStyle.secondary)
                .frame(width: 36)
            Menu {
                Button("Użyj ustawień") { model.reuse(song); page = "create" }
                Button("Pokaż w Finderze") { model.reveal(song) }
            } label: { Image(systemName: "ellipsis").frame(width: 20) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 22)
        }
        .padding(15)
        .background(model.selectedSong?.id == song.id ? StudioStyle.amber.opacity(0.045) : StudioStyle.surface,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedSong?.id == song.id ? StudioStyle.amber.opacity(0.3) : Color.clear, lineWidth: 1))
    }

    private var player: some View {
        HStack(spacing: 18) {
            if let song = model.selectedSong {
                Image(systemName: "waveform").font(.system(size: 23)).foregroundStyle(StudioStyle.amber)
                    .frame(width: 37)
                VStack(alignment: .leading, spacing: 5) {
                    Text(song.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text("\(song.format.uppercased()) · \(timeLabel(song.duration))")
                        .font(.system(size: 10)).foregroundStyle(StudioStyle.secondary)
                }.frame(width: 195, alignment: .leading)
                Button { model.play(song) } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16)).frame(width: 35, height: 35)
                }.buttonStyle(.plain).help("Odtwórz lub wstrzymaj")
                Text(timeLabel(model.playbackTime)).font(.system(size: 10)).monospacedDigit().foregroundStyle(StudioStyle.secondary)
                Slider(value: Binding(get: { min(model.playbackTime, max(1, model.playbackDuration)) },
                                      set: { model.seek(to: $0) }), in: 0...max(1, model.playbackDuration))
                    .accessibilityLabel("Pozycja odtwarzania")
                Text(timeLabel(model.playbackDuration)).font(.system(size: 10)).monospacedDigit().foregroundStyle(StudioStyle.secondary)
                Button { model.reveal(song) } label: { Image(systemName: "folder") }
                    .buttonStyle(.plain).help("Pokaż plik w Finderze")
                Button { model.reuse(song); page = "create" } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.plain).help("Użyj ustawień utworu")
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 16)
        .background(StudioStyle.surface)
        .overlay(alignment: .top) { separator }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(StudioStyle.amber)
            Text(message).font(.system(size: 12)).textSelection(.enabled)
            Spacer()
            Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).help("Zamknij komunikat")
        }
        .padding(15).background(StudioStyle.amber.opacity(0.08))
    }

    private var separator: some View { Rectangle().fill(StudioStyle.line).frame(height: 1) }
    private func sectionLabel(_ label: String) -> some View {
        Text(label).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(StudioStyle.secondary)
    }
    private func timeLabel(_ value: Double) -> String {
        let seconds = max(0, Int(value.isFinite ? value : 0))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct StudioTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let label: String
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder).foregroundStyle(StudioStyle.secondary.opacity(0.65))
                    .padding(.horizontal, 5).padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .accessibilityLabel(label)
                .font(.system(size: 13))
                .lineSpacing(4)
        }
        .font(.system(size: 13))
        .padding(11)
        .frame(height: height)
        .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioStyle.line, lineWidth: 1))
    }
}
