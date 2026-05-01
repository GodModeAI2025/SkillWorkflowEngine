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
            ScratchStyle.headerNumber(1, color: ScratchStyle.looksPurple)

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
                BuildGuideRow(number: 1, title: "Daten", detail: "Ordner oder Text angeben", color: ScratchStyle.motionBlue)
                BuildGuideRow(number: 2, title: "WAS", detail: "Arbeit oder Prüfung ziehen", color: ScratchStyle.looksPurple)
                BuildGuideRow(number: 3, title: "WER", detail: "optional Perspektive ergänzen", color: ScratchStyle.variablesOrange)
                BuildGuideRow(number: 4, title: "Start", detail: "Ergebnis prüfen oder Feedback geben", color: ScratchStyle.operatorsGreen)
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

            LazyVStack(spacing: 8) {
                ForEach(itemsForMode) { item in
                    LibraryRow(item: item)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    switch mode {
                    case .what:
                        ForEach(WhatFilter.allCases) { filter in
                            FilterChip(
                                title: filter.label,
                                isSelected: whatFilter == filter,
                                color: filter.color
                            ) {
                                whatFilter = filter
                            }
                        }
                    case .who:
                        ForEach(WhoFilter.allCases) { filter in
                            FilterChip(
                                title: filter.label,
                                isSelected: whoFilter == filter,
                                color: filter.color
                            ) {
                                whoFilter = filter
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
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
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.11), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(isSelected ? 0 : 0.35)))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
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
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
    }

    private var text: String {
        switch mode {
        case .what:
            return whatFilter.description
        case .who:
            return whoFilter.description
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
            return "WAS sind ausführbare Blöcke: Arbeit, Analyse, Schreiben, QS und Finale."
        case .analyze:
            return "Analysieren zeigt Blöcke, die verstehen, bewerten, vergleichen oder Risiken finden."
        case .create:
            return "Erstellen zeigt Blöcke, die Texte, ADRs, Reports, PRs oder Zusammenfassungen erzeugen."
        case .quality:
            return "Prüfen/QS zeigt Quality Gates, Lektorat, kritische Reviews und Abschlussprüfungen."
        case .decide:
            return "Entscheiden zeigt Blöcke für Strategie, Priorisierung, Business Case und Entscheidungsvorlagen."
        case .automate:
            return "Automatisieren zeigt Blöcke mit Prozess-, Technik-, Agenten- oder Umsetzungsbezug."
        }
    }

    var color: Color {
        switch self {
        case .all: return ScratchStyle.looksPurple
        case .analyze: return ScratchStyle.sensingBlue
        case .create: return ScratchStyle.looksPurple
        case .quality: return ScratchStyle.operatorsGreen
        case .decide: return ScratchStyle.eventYellow
        case .automate: return ScratchStyle.motionBlue
        }
    }

    func matches(_ item: LibraryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .analyze:
            return item.matchesAny(["analyse", "analysis", "analys", "review", "bewert", "audit", "diagnos", "risk", "risiko", "architektur", "architecture", "security", "strategie"])
        case .create:
            return item.matchesAny(["schreib", "dokument", "report", "adr", "pr-", "pull request", "folie", "summary", "zusammenfass", "text", "redaktion", "lektor"])
        case .quality:
            return item.kind == .qualityGate || item.matchesAny(["prüf", "pruef", "qs", "quality", "lektor", "review", "kritisch", "valid", "check", "gate", "sicherheit"])
        case .decide:
            return item.matchesAny(["entscheidung", "decision", "strategie", "prioris", "business case", "management", "governance", "roadmap", "invest", "kosten"])
        case .automate:
            return item.matchesAny(["agent", "workflow", "prozess", "automation", "orchestr", "backoffice", "service", "operation", "code", "developer", "engineer"])
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
            return "WER-Blöcke ändern die Perspektive, Haltung oder Sprache eines WAS-Blocks."
        case .domain:
            return "Fachrolle zeigt berufliche Perspektiven wie Architektur, Engineering, Betrieb, Security oder Finance."
        case .leadership:
            return "Führung zeigt strategische, Management- und Entscheider-Perspektiven."
        case .creative:
            return "Kreativ zeigt visionäre, gestalterische oder ungewohnte Denkhaltungen."
        case .critical:
            return "Kritisch zeigt skeptische, prüfende oder risiko-orientierte Perspektiven."
        case .communication:
            return "Kommunikation zeigt Perspektiven für Story, Redaktion, Marketing, Moderation oder Anschlussfähigkeit."
        }
    }

    var color: Color {
        switch self {
        case .all: return ScratchStyle.variablesOrange
        case .domain: return ScratchStyle.motionBlue
        case .leadership: return ScratchStyle.eventYellow
        case .creative: return ScratchStyle.soundPink
        case .critical: return ScratchStyle.controlOrange
        case .communication: return ScratchStyle.variablesOrange
        }
    }

    func matches(_ item: LibraryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .domain:
            return item.matchesAny(["architect", "architekt", "engineer", "developer", "manager", "specialist", "technician", "security", "data", "cloud", "software", "infrastruktur", "infrastructure", "finance", "business"])
        case .leadership:
            return item.matchesAny(["ceo", "cfo", "cto", "leader", "führung", "management", "stratege", "investor", "mogul", "direktor", "executive", "bezos", "jobs", "musk"])
        case .creative:
            return item.matchesAny(["creative", "kreativ", "design", "vision", "innov", "artist", "autor", "philosoph", "community", "evangelist", "verlag"])
        case .critical:
            return item.matchesAny(["krit", "skept", "risk", "risiko", "challenge", "auditor", "security", "compliance", "jurist", "controlling", "verteidigung"])
        case .communication:
            return item.matchesAny(["kommunikation", "marketing", "reporter", "lektor", "editor", "moderator", "coach", "sales", "story", "redaktion"])
        }
    }
}

private extension LibraryItem {
    func matchesAny(_ keywords: [String]) -> Bool {
        let haystack = [
            id,
            name,
            title,
            summary,
            tags.joined(separator: " "),
            content
        ]
            .joined(separator: " ")
            .lowercased()

        return keywords.contains { haystack.contains($0.lowercased()) }
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
                Text(item.kind.label)
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
}
