import AppKit
import SwiftUI

struct DataLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTemplateID = ""
    @State private var mode: LibraryMode = .what
    @State private var whatFilter: WhatFilter = .all
    @State private var whoFilter: WhoFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    paletteHeader
                    buildGuideSection
                    modeSection
                    workflowSection
                    sourceSection
                    templateSection
                    librarySection
                }
                .padding(20)
            }
        }
        .background(ScratchStyle.paletteBackground)
    }

    private var paletteHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ScratchStyle.headerNumber(1, color: Color.nwebTextSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Bausteine")
                    .font(.nwebTitle)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text("Daten wählen und Blöcke in den Ablauf ziehen.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var buildGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ablauf bauen", systemImage: "hand.draw")
                .font(.nwebHeadline)
                .foregroundStyle(ScratchStyle.motionBlue)

            Text("Wähle Daten, ziehe Bausteine in die Mitte und starte rechts. Der Ablauf läuft von oben nach unten.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)

            VStack(alignment: .leading, spacing: 8) {
                BuildGuideRow(number: 1, title: "Daten", detail: "Ordner oder Text angeben", color: Color.nwebTextSecondary)
                BuildGuideRow(number: 2, title: "WAS", detail: "Arbeit oder Prüfung ziehen", color: ScratchStyle.looksPurple)
                BuildGuideRow(number: 3, title: "WER", detail: "optional Perspektive ergänzen", color: ScratchStyle.variablesOrange)
                BuildGuideRow(number: 4, title: "Start", detail: "Ergebnis prüfen oder Feedback geben", color: Color.nwebTextSecondary)
            }
        }
        .scratchPanel()
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Arbeitsmodus", systemImage: "slider.horizontal.3")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Arbeitsmodus",
                message: WorkflowMode.allCases.map { "\($0.label): \($0.description)" }.joined(separator: "\n\n")
            ) {
                Picker("Arbeitsmodus", selection: $store.workflowMode) {
                    ForEach(WorkflowMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: store.workflowMode) { _, _ in
                    store.saveSettings()
                }
            }

            Text(store.workflowMode.description)
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
        .scratchPanel()
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Auftrag & Daten", systemImage: "tray.full")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            TextField("Ablauf-Name", text: Binding(
                get: { store.workflow.name },
                set: { newValue in
                    store.workflow.name = newValue
                    store.markWorkflowEdited()
                }
            ))
            .disabled(store.workflowMode == .audit)

            HStack {
                TextField("Datenordner oder Projektordner", text: Binding(
                    get: { store.workflow.input.folderPath },
                    set: { newValue in
                        store.workflow.input.folderPath = newValue
                        store.markWorkflowEdited()
                    }
                ))
                Button {
                    chooseFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Ordner wählen")
            }
            .disabled(store.workflowMode == .audit)

            Text("Arbeitsverzeichnis")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
            HStack {
                TextField("Zwischenspeicher für Run-Stände", text: $store.workDirectoryPath)
                    .onSubmit {
                        store.saveSettings()
                    }
                Button {
                    chooseWorkDirectory()
                } label: {
                    Image(systemName: "externaldrive")
                }
                .help("Arbeitsverzeichnis wählen")
            }
            .disabled(store.workflowMode == .audit)

            Group {
                Text("Ziel")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Was soll erreicht werden?", text: Binding(
                    get: { store.workflow.input.goal },
                    set: { newValue in
                        store.workflow.input.goal = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Kontext")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Einkauf, Architekturentscheidung, Compliance-Prüfung...", text: Binding(
                    get: { store.workflow.input.context },
                    set: { newValue in
                        store.workflow.input.context = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Gewünschtes Ergebnis")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Entscheidungsvorlage, Review, Folienstruktur...", text: Binding(
                    get: { store.workflow.input.desiredResult },
                    set: { newValue in
                        store.workflow.input.desiredResult = newValue
                        store.markWorkflowEdited()
                    }
                ))

                Text("Kriterien")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                TextField("Kosten, Sicherheit, Strategie-Fit, Umsetzbarkeit...", text: Binding(
                    get: { store.workflow.input.criteria },
                    set: { newValue in
                        store.workflow.input.criteria = newValue
                        store.markWorkflowEdited()
                    }
                ))
            }
            .disabled(store.workflowMode == .audit)

            Text("Freitext-Zusatz")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
            TextEditor(text: Binding(
                get: { store.workflow.input.prompt },
                set: { newValue in
                    store.workflow.input.prompt = newValue
                    store.markWorkflowEdited()
                }
            ))
            .frame(minHeight: 92)
            .nwebInputBackground()
            .disabled(store.workflowMode == .audit)
        }
        .scratchPanel()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Skill-Bibliothek", systemImage: "books.vertical")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            HStack {
                TextField("Pfad zur Skill-Bibliothek", text: $store.libraryPath)
                Button("Laden") {
                    store.saveSettings()
                    Task { await store.loadLibrary() }
                }
            }
            if let library = store.library {
                Text("\(library.items.count) Bausteine · \(library.templates.count) Vorlagen")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            } else {
                Text(store.errorMessage.isEmpty ? "Bibliothek nicht geladen." : store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
        }
        .scratchPanel()
        .disabled(store.workflowMode != .edit)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fertige Abläufe", systemImage: "rectangle.stack")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Vorlage",
                message: "Wählt einen vorbereiteten Ablauf aus der Skill-Bibliothek. Übernehmen füllt daraus die Prozesskette mit passenden WAS-Schritten."
            ) {
                Picker("Vorlage", selection: $selectedTemplateID) {
                    Text("Keine Vorlage").tag("")
                    ForEach(store.library?.templates ?? []) { template in
                        Text("\(template.id) · \(template.title)").tag(template.id)
                    }
                }
                .labelsHidden()
            }

            Button("Vorlage als Prozess übernehmen") {
                guard let template = store.library?.templates.first(where: { $0.id == selectedTemplateID }) else { return }
                store.loadTemplate(template)
            }
            .disabled(selectedTemplateID.isEmpty)

            Button {
                store.loadDemoWorkflow()
            } label: {
                Label("Demo-Prozess laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.library == nil)
        }
        .scratchPanel()
        .disabled(store.workflowMode != .edit)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Block-Palette", systemImage: "square.grid.3x3")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            TextField("Suchen: prüfen, schreiben, zusammenfassen...", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            ColorLogicNote()

            InfoControlRow(
                "Baustein-Art",
                message: "WAS sind ausführbare Blöcke: analysieren, schreiben, prüfen, QS, finalisieren. WER verändert die Perspektive eines WAS-Blocks, erzeugt aber keinen eigenen Arbeitsschritt."
            ) {
                Picker("Baustein-Art", selection: $mode) {
                    ForEach(LibraryMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            filterBar

            CategoryHint(mode: mode, whatFilter: whatFilter, whoFilter: whoFilter)

            Text("\(itemsForMode.count) passende Blöcke")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)

            if itemsForMode.isEmpty {
                EmptyFilterState()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(itemsForMode) { item in
                        LibraryRow(item: item)
                    }
                }
            }
        }
        .scratchPanel()
        .disabled(store.workflowMode != .edit)
    }

    private var itemsForMode: [LibraryItem] {
        switch mode {
        case .what:
            return store.filteredItems()
                .filter { $0.kind == .consultingAgent || $0.kind == .jobSkill || $0.kind == .qualityGate }
                .filter { whatFilter.matches($0) }
        case .who:
            return store.filteredItems(kind: .personaSkill)
                .filter { whoFilter.matches($0) }
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        let columns = [
            GridItem(.adaptive(minimum: 136), spacing: 8)
        ]

        VStack(alignment: .leading, spacing: 8) {
            Text("Filter")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                switch mode {
                case .what:
                    ForEach(WhatFilter.allCases) { filter in
                        FilterChip(
                            title: filter.label,
                            count: count(for: filter),
                            isSelected: whatFilter == filter,
                            color: filter.color,
                            selectedForeground: filter.selectedForeground
                        ) {
                            whatFilter = filter
                        }
                    }
                case .who:
                    ForEach(WhoFilter.allCases) { filter in
                        FilterChip(
                            title: filter.label,
                            count: count(for: filter),
                            isSelected: whoFilter == filter,
                            color: filter.color,
                            selectedForeground: filter.selectedForeground
                        ) {
                            whoFilter = filter
                        }
                    }
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.workflow.input.folderPath = url.path
            store.markWorkflowEdited()
        }
    }

    private func chooseWorkDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.workDirectoryPath = url.path
            store.saveSettings()
        }
    }

    private func count(for filter: WhatFilter) -> Int {
        store.filteredItems()
            .filter { $0.kind == .consultingAgent || $0.kind == .jobSkill || $0.kind == .qualityGate }
            .filter { filter.matches($0) }
            .count
    }

    private func count(for filter: WhoFilter) -> Int {
        store.filteredItems(kind: .personaSkill)
            .filter { filter.matches($0) }
            .count
    }
}

private struct BuildGuideRow: View {
    let number: Int
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let selectedForeground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isSelected ? selectedForeground : color).opacity(0.16), in: Capsule())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? selectedForeground : color)
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 11)
            .background(isSelected ? color : color.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(isSelected ? 0 : 0.40), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

private struct ColorLogicNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Farblogik")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)

            Text("Blockrand bleibt beim Ziehen erhalten: Violett = WAS, Grün = QS, Orange = WER. Filterchips haben eigene Farben; ihre Zahl zeigt die Treffer in der Liste.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                LegendPill(color: ScratchStyle.looksPurple, text: "WAS")
                LegendPill(color: ScratchStyle.operatorsGreen, text: "QS")
                LegendPill(color: ScratchStyle.variablesOrange, text: "WER")
            }
        }
        .padding(10)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }
}

private struct LegendPill: View {
    let color: Color
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 22)
            .background(color, in: Capsule())
    }
}

private struct EmptyFilterState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Keine Treffer", systemImage: "line.3.horizontal.decrease.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebTextPrimary)
            Text("Der aktive Filter und die Suche schließen gerade alle Blöcke aus.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                .stroke(Color.nwebBorder)
        )
    }
}

private struct CategoryHint: View {
    let mode: LibraryMode
    let whatFilter: WhatFilter
    let whoFilter: WhoFilter

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aktiver Filter: \(label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                Text("\(text) \(resultSentence)")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
    }

    private var label: String {
        switch mode {
        case .what:
            return whatFilter.label
        case .who:
            return whoFilter.label
        }
    }

    private var text: String {
        switch mode {
        case .what:
            return whatFilter.description
        case .who:
            return whoFilter.description
        }
    }

    private var resultSentence: String {
        switch mode {
        case .what:
            return whatFilter == .all
                ? "Die Liste darunter zeigt alle passenden WAS- und QS-Blöcke."
                : "Die Liste darunter zeigt nur diese Kategorie."
        case .who:
            return whoFilter == .all
                ? "Die Liste darunter zeigt alle passenden WER-Blöcke."
                : "Die Liste darunter zeigt nur diese Kategorie."
        }
    }

    private var color: Color {
        switch mode {
        case .what:
            return whatFilter.color
        case .who:
            return whoFilter.color
        }
    }
}

private enum LibraryMode: String, CaseIterable, Identifiable {
    case what
    case who

    var id: String { rawValue }
    var label: String {
        switch self {
        case .what: return "WAS"
        case .who: return "WER"
        }
    }
}

private enum WhatFilter: String, CaseIterable, Identifiable {
    case all
    case analyze
    case create
    case quality
    case decide
    case automate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Alle"
        case .analyze: return "Analysieren"
        case .create: return "Erstellen"
        case .quality: return "Prüfen/QS"
        case .decide: return "Entscheiden"
        case .automate: return "Automatisieren"
        }
    }

    var description: String {
        switch self {
        case .all:
            return "Alle WAS- und QS-Blöcke, die zur Suche passen."
        case .analyze:
            return "Nur Blöcke, die verstehen, bewerten, vergleichen oder Risiken finden."
        case .create:
            return "Nur Blöcke, die ein sichtbares Artefakt erzeugen: Text, Report, ADR, PR oder Folienstruktur."
        case .quality:
            return "Nur Prüf-, Lektorats-, Audit- und Quality-Gate-Blöcke."
        case .decide:
            return "Nur Blöcke für Strategie, Priorisierung, Business Case und Entscheidungsvorlagen."
        case .automate:
            return "Nur Blöcke mit Prozess-, Betriebs-, Engineering- oder Umsetzungsbezug."
        }
    }

    var color: Color {
        switch self {
        case .all: return Color.nwebTextSecondary
        case .analyze: return ScratchStyle.sensingBlue
        case .create: return ScratchStyle.soundPink
        case .quality: return ScratchStyle.operatorsGreen
        case .decide: return ScratchStyle.controlOrange
        case .automate: return ScratchStyle.motionBlue
        }
    }

    var selectedForeground: Color {
        switch self {
        case .all, .analyze, .create, .quality, .automate:
            return .white
        case .decide:
            return Color.nwebTextPrimary
        }
    }

    func matches(_ item: LibraryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .analyze:
            return item.matchesIdentity([
                "analyse", "analysis", "analyst", "analytics", "problemloser", "marktexperte",
                "prognostiker", "architect", "architekt", "security", "auditor", "risk", "risiko"
            ])
        case .create:
            return item.matchesIdentity([
                "reporter", "redakteur", "dokument", "documentation", "requirements",
                "designer", "ux", "ui", "product-owner", "summary", "folio", "pr-"
            ])
        case .quality:
            return item.kind == .qualityGate || item.matchesIdentity([
                "lektor", "auditor", "security", "compliance", "soc", "quality", "pruef", "pruf", "qs"
            ])
        case .decide:
            return item.matchesIdentity([
                "stratege", "strategy", "strategic", "purchaser", "head-of-it",
                "business", "backoffice", "personalchef", "product-owner", "management", "finance"
            ])
        case .automate:
            return item.matchesIdentity([
                "operations", "devops", "release", "application", "cloud", "developer",
                "engineer", "technician", "service", "support", "sap", "workflow", "orchestr"
            ])
        }
    }
}

private enum WhoFilter: String, CaseIterable, Identifiable {
    case all
    case domain
    case leadership
    case creative
    case critical
    case communication

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Alle"
        case .domain: return "Fachrolle"
        case .leadership: return "Führung"
        case .creative: return "Kreativ"
        case .critical: return "Kritisch"
        case .communication: return "Kommunikation"
        }
    }

    var description: String {
        switch self {
        case .all:
            return "Alle WER-Blöcke, die zur Suche passen."
        case .domain:
            return "Fachliche Perspektiven mit Experten-, Wissenschafts-, Rechts-, Energie- oder Finanzbezug."
        case .leadership:
            return "Unternehmer-, Tech-Leader- und Entscheider-Perspektiven."
        case .creative:
            return "Produkt-, Design-, Medien- und visionäre Denkhaltungen."
        case .critical:
            return "Skeptische, rechtliche, politische, risiko- oder kontrollorientierte Perspektiven."
        case .communication:
            return "Perspektiven für Sprache, Story, Öffentlichkeit, Moderation und Anschlussfähigkeit."
        }
    }

    var color: Color {
        switch self {
        case .all: return Color.nwebTextSecondary
        case .domain: return ScratchStyle.sensingBlue
        case .leadership: return ScratchStyle.controlOrange
        case .creative: return ScratchStyle.looksPurple
        case .critical: return ScratchStyle.myBlocksRed
        case .communication: return ScratchStyle.soundPink
        }
    }

    var selectedForeground: Color {
        switch self {
        case .all, .domain, .creative, .critical, .communication:
            return .white
        case .leadership:
            return Color.nwebTextPrimary
        }
    }

    func matches(_ item: LibraryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .domain:
            return item.matchesProfile([
                "wissenschaftler", "rechts", "jurist", "energie", "gesundheit", "daten",
                "biotechnologie", "finanz", "bank", "philosoph"
            ])
        case .leadership:
            return item.matchesProfile([
                "unternehmer", "tech leader", "fuehrung", "fuhrung", "management",
                "strategischer berater", "investor", "mogul", "bezos", "jobs", "musk", "nadella"
            ])
        case .creative:
            return item.matchesProfile([
                "kreativ", "design", "vision", "produkt", "fotografie", "medien",
                "verlag", "schreiber", "artist", "community", "evangelist", "innovation"
            ])
        case .critical:
            return item.matchesProfile([
                "krit", "skept", "risiko", "rechts", "jurist", "staats", "politik",
                "bank", "finanz", "diplomat", "verteidigung", "compliance", "reform"
            ])
        case .communication:
            return item.matchesProfile([
                "kommunikation", "rhetorik", "redner", "volksredner", "story",
                "marketing", "medien", "moderator", "coach", "sales", "schreiber", "verlag"
            ])
        }
    }
}

private extension LibraryItem {
    func matchesIdentity(_ keywords: [String]) -> Bool {
        containsAny(keywords, in: [
            id,
            name,
            title
        ])
    }

    func matchesProfile(_ keywords: [String]) -> Bool {
        containsAny(keywords, in: [
            id,
            name,
            title,
            summary
        ])
    }

    private func containsAny(_ keywords: [String], in fields: [String]) -> Bool {
        let haystack = normalize(fields.joined(separator: " "))
        return keywords.contains { haystack.contains(normalize($0)) }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

struct LibraryRow: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .frame(width: 16)
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.nwebTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text(badgeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .padding(.leading, 8)
        .scratchBlock(color: accentColor)
        .onDrag {
            NSItemProvider(object: item.dragPayload as NSString)
        }
    }

    private var icon: String {
        switch item.kind {
        case .personaSkill: return "person.crop.circle"
        case .qualityGate: return "checkmark.seal"
        case .jobSkill: return "briefcase"
        case .consultingAgent: return "person.text.rectangle"
        case .rootSkill: return "building.columns"
        }
    }

    private var accentColor: Color {
        ScratchStyle.blockColor(for: item.kind)
    }

    private var badgeTitle: String {
        switch item.kind {
        case .personaSkill:
            return "WER"
        case .qualityGate:
            return "QS"
        case .consultingAgent, .jobSkill:
            return "WAS"
        case .rootSkill:
            return "ROOT"
        }
    }
}
