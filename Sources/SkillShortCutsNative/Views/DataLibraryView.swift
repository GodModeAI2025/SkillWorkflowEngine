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
                    modeSection
                    workflowSection
                    sourceSection
                    templateSection
                    librarySection
                }
                .padding(20)
            }
        }
        .background(PipesStyle.paneBackground)
    }

    private var paletteHeader: some View {
        PipePaneHeader(
            number: 1,
            title: "Library",
            subtitle: "Quellen, Eingaben und Module auswählen und auf den Pipe Canvas ziehen.",
            color: PipesStyle.sourceBlue
        )
        .padding(-20)
        .padding(.bottom, 2)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pipe Mode", systemImage: "slider.horizontal.3")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Pipe Mode",
                message: WorkflowMode.allCases.map { "\($0.label): \($0.description)" }.joined(separator: "\n\n")
            ) {
                Picker("Pipe Mode", selection: $store.workflowMode) {
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
        .pipePanel(color: Color.nwebAccent)
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Source & Inputs", systemImage: "tray.full")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

                TextField("Pipe-Name", text: Binding(
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
                TextField("Zwischenspeicher für Pipe-Läufe", text: $store.workDirectoryPath)
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
        .pipePanel(color: PipesStyle.sourceBlue)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Module Repository", systemImage: "books.vertical")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            HStack {
                TextField("Pfad zur Modul-Bibliothek", text: $store.libraryPath)
                Button("Laden") {
                    store.saveSettings()
                    Task { await store.loadLibrary() }
                }
            }
            if let library = store.library {
                Text("\(library.items.count) Module · \(library.templates.count) Pipe-Vorlagen")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            } else {
                Text(store.errorMessage.isEmpty ? "Bibliothek nicht geladen." : store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
        }
        .pipePanel(color: PipesStyle.operatorPurple)
        .disabled(store.workflowMode != .edit)
    }

    private var templateSection: some View {
        let canEdit = store.workflowMode == .edit
        let canLoadTemplate = canEdit && !selectedTemplateID.isEmpty
        let canLoadDemo = canEdit && store.library != nil

        return VStack(alignment: .leading, spacing: 8) {
            Label("Saved Pipes", systemImage: "rectangle.stack")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            InfoControlRow(
                "Vorlage",
                message: "Wählt eine vorbereitete Pipe aus der Modul-Bibliothek. Übernehmen füllt daraus die Prozesskette mit passenden WAS-Modulen."
            ) {
                Menu {
                    Button("Keine Vorlage") {
                        selectedTemplateID = ""
                    }
                    ForEach(store.library?.templates ?? []) { template in
                        Button("\(template.id) · \(template.title)") {
                            selectedTemplateID = template.id
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedTemplateTitle)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.body.weight(.semibold))
                    }
                    .pipeControlSurface(isEnabled: canEdit)
                }
                .buttonStyle(.plain)
                .disabled(!canEdit)
            }

            Button("Vorlage als Pipe übernehmen") {
                guard let template = store.library?.templates.first(where: { $0.id == selectedTemplateID }) else { return }
                store.loadTemplate(template)
            }
            .buttonStyle(PipeSecondaryButtonStyle())
            .disabled(!canLoadTemplate)

            Button {
                store.loadDemoWorkflow()
            } label: {
                Label("Demo-Pipe laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canLoadDemo)
        }
        .pipePanel(color: PipesStyle.outputTeal)
    }

    private var selectedTemplateTitle: String {
        guard !selectedTemplateID.isEmpty,
              let template = store.library?.templates.first(where: { $0.id == selectedTemplateID })
        else { return "Keine Vorlage" }

        return "\(template.id) · \(template.title)"
    }

    @ViewBuilder
    private var librarySection: some View {
        let snapshot = paletteSnapshot()

        VStack(alignment: .leading, spacing: 10) {
            Label("Module Palette", systemImage: "square.grid.3x3")
                .font(.nwebHeadline)
                .foregroundStyle(Color.nwebAccent)

            TextField("Module suchen: prüfen, schreiben, zusammenfassen...", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            ColorLogicNote()

            InfoControlRow(
                "Modultyp",
                message: "Operator/WAS-Module verarbeiten Daten im Pipe-Fluss. Persona/WER-Module parametrisieren einen Operator, erzeugen aber keinen eigenen Arbeitsschritt."
            ) {
                Picker("Modultyp", selection: $mode) {
                    ForEach(LibraryMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            filterBar(snapshot: snapshot)

            CategoryHint(mode: mode, whatFilter: whatFilter, whoFilter: whoFilter)

            Text("\(snapshot.visibleItems.count) passende Module")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)

            if snapshot.visibleItems.isEmpty {
                EmptyFilterState()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(snapshot.visibleItems) { item in
                        LibraryRow(item: item)
                    }
                }
            }
        }
        .pipePanel(color: mode == .what ? PipesStyle.operatorPurple : PipesStyle.personaOrange)
        .disabled(store.workflowMode != .edit)
    }

    @ViewBuilder
    private func filterBar(snapshot: PaletteSnapshot) -> some View {
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
                            count: snapshot.count(for: filter),
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
                            count: snapshot.count(for: filter),
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

    private func paletteSnapshot() -> PaletteSnapshot {
        let indexedItems = store.filteredItems().map(PaletteIndexedItem.init)
        let whatItems = indexedItems.filter { $0.item.kind.isWhatPaletteKind }
        let whoItems = indexedItems.filter { $0.item.kind == .personaSkill }

        switch mode {
        case .what:
            let counts = WhatFilter.counts(in: whatItems)
            return PaletteSnapshot(
                visibleItems: whatItems.filter { whatFilter.matches($0) }.map(\.item),
                whatCounts: counts,
                whoCounts: [:]
            )
        case .who:
            let counts = WhoFilter.counts(in: whoItems)
            return PaletteSnapshot(
                visibleItems: whoItems.filter { whoFilter.matches($0) }.map(\.item),
                whatCounts: [:],
                whoCounts: counts
            )
        }
    }
}

private struct PaletteSnapshot {
    let visibleItems: [LibraryItem]
    let whatCounts: [WhatFilter: Int]
    let whoCounts: [WhoFilter: Int]

    func count(for filter: WhatFilter) -> Int {
        whatCounts[filter, default: 0]
    }

    func count(for filter: WhoFilter) -> Int {
        whoCounts[filter, default: 0]
    }
}

private struct PaletteIndexedItem {
    let item: LibraryItem
    private let identityText: String
    private let profileText: String

    init(item: LibraryItem) {
        self.item = item
        identityText = Self.normalize("\(item.id) \(item.name) \(item.title)")
        profileText = Self.normalize("\(item.id) \(item.name) \(item.title) \(item.summary)")
    }

    func identityContainsAny(_ keywords: [String]) -> Bool {
        containsAny(keywords, in: identityText)
    }

    func profileContainsAny(_ keywords: [String]) -> Bool {
        containsAny(keywords, in: profileText)
    }

    private func containsAny(_ keywords: [String], in haystack: String) -> Bool {
        keywords.contains { haystack.contains(Self.normalize($0)) }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
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

            Text("Modulrand bleibt beim Ziehen erhalten: Lila = Operator/WAS, Grün = QS, Orange = Persona/WER. Filterchips haben eigene Farben; ihre Zahl zeigt Treffer.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                LegendPill(color: PipesStyle.operatorPurple, text: "WAS")
                LegendPill(color: PipesStyle.qualityGreen, text: "QS")
                LegendPill(color: PipesStyle.personaOrange, text: "WER")
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
            Label("Keine Module", systemImage: "line.3.horizontal.decrease.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebTextPrimary)
            Text("Der aktive Filter und die Suche schließen gerade alle Module aus.")
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
                ? "Die Liste darunter zeigt alle passenden WAS- und QS-Module."
                : "Die Liste darunter zeigt nur diese Kategorie."
        case .who:
            return whoFilter == .all
                ? "Die Liste darunter zeigt alle passenden WER-Module."
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
        case .what: return "Operator"
        case .who: return "Persona"
        }
    }
}

private enum WhatFilter: String, CaseIterable, Identifiable, Hashable {
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
            return "Alle Operator- und QS-Module, die zur Suche passen."
        case .analyze:
            return "Nur Module, die verstehen, bewerten, vergleichen oder Risiken finden."
        case .create:
            return "Nur Module, die ein sichtbares Artefakt erzeugen: Text, Report, ADR, PR oder Folienstruktur."
        case .quality:
            return "Nur Prüf-, Lektorats-, Audit- und Quality-Gate-Module."
        case .decide:
            return "Nur Module für Strategie, Priorisierung, Business Case und Entscheidungsvorlagen."
        case .automate:
            return "Nur Module mit Prozess-, Betriebs-, Engineering- oder Umsetzungsbezug."
        }
    }

    var color: Color {
        switch self {
        case .all: return Color.nwebTextSecondary
        case .analyze: return PipesStyle.sourceBlue
        case .create: return Color.dynamic(light: 0xB85BA8, dark: 0xE48AD6)
        case .quality: return PipesStyle.qualityGreen
        case .decide: return PipesStyle.personaOrange
        case .automate: return PipesStyle.outputTeal
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

    static func counts(in items: [PaletteIndexedItem]) -> [WhatFilter: Int] {
        Dictionary(uniqueKeysWithValues: allCases.map { filter in
            (filter, items.lazy.filter { filter.matches($0) }.count)
        })
    }

    func matches(_ item: PaletteIndexedItem) -> Bool {
        switch self {
        case .all:
            return true
        case .analyze:
            return item.identityContainsAny([
                "analyse", "analysis", "analyst", "analytics", "problemloser", "marktexperte",
                "prognostiker", "architect", "architekt", "security", "auditor", "risk", "risiko"
            ])
        case .create:
            return item.identityContainsAny([
                "reporter", "redakteur", "dokument", "documentation", "requirements",
                "designer", "ux", "ui", "product-owner", "summary", "folio", "pr-"
            ])
        case .quality:
            return item.item.kind == .qualityGate || item.identityContainsAny([
                "lektor", "auditor", "security", "compliance", "soc", "quality", "pruef", "pruf", "qs"
            ])
        case .decide:
            return item.identityContainsAny([
                "stratege", "strategy", "strategic", "purchaser", "head-of-it",
                "business", "backoffice", "personalchef", "product-owner", "management", "finance"
            ])
        case .automate:
            return item.identityContainsAny([
                "operations", "devops", "release", "application", "cloud", "developer",
                "engineer", "technician", "service", "support", "sap", "workflow", "orchestr"
            ])
        }
    }
}

private enum WhoFilter: String, CaseIterable, Identifiable, Hashable {
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
            return "Alle Persona-Module, die zur Suche passen."
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
        case .domain: return PipesStyle.sourceBlue
        case .leadership: return PipesStyle.personaOrange
        case .creative: return PipesStyle.operatorPurple
        case .critical: return Color.dynamic(light: 0xC7474D, dark: 0xF06E73)
        case .communication: return Color.dynamic(light: 0xB85BA8, dark: 0xE48AD6)
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

    static func counts(in items: [PaletteIndexedItem]) -> [WhoFilter: Int] {
        Dictionary(uniqueKeysWithValues: allCases.map { filter in
            (filter, items.lazy.filter { filter.matches($0) }.count)
        })
    }

    func matches(_ item: PaletteIndexedItem) -> Bool {
        switch self {
        case .all:
            return true
        case .domain:
            return item.profileContainsAny([
                "wissenschaftler", "rechts", "jurist", "energie", "gesundheit", "daten",
                "biotechnologie", "finanz", "bank", "philosoph"
            ])
        case .leadership:
            return item.profileContainsAny([
                "unternehmer", "tech leader", "fuehrung", "fuhrung", "management",
                "strategischer berater", "investor", "mogul", "bezos", "jobs", "musk", "nadella"
            ])
        case .creative:
            return item.profileContainsAny([
                "kreativ", "design", "vision", "produkt", "fotografie", "medien",
                "verlag", "schreiber", "artist", "community", "evangelist", "innovation"
            ])
        case .critical:
            return item.profileContainsAny([
                "krit", "skept", "risiko", "rechts", "jurist", "staats", "politik",
                "bank", "finanz", "diplomat", "verteidigung", "compliance", "reform"
            ])
        case .communication:
            return item.profileContainsAny([
                "kommunikation", "rhetorik", "redner", "volksredner", "story",
                "marketing", "medien", "moderator", "coach", "sales", "schreiber", "verlag"
            ])
        }
    }
}

private extension LibraryItemKind {
    var isWhatPaletteKind: Bool {
        switch self {
        case .consultingAgent, .jobSkill, .qualityGate:
            return true
        case .rootSkill, .personaSkill:
            return false
        }
    }
}

struct LibraryRow: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PipePort(color: accentColor)
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
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .padding(.top, 4)
        .pipeModule(color: accentColor)
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
        PipesStyle.moduleColor(for: item.kind)
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
