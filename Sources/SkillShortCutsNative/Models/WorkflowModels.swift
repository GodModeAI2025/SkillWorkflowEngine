import Foundation

enum ConsultantRole: String, Codable, CaseIterable, Identifiable {
    case lead = "LEAD"
    case support = "SUPPORT"
    case challenge = "CHALLENGE"
    case independent = "INDEPENDENT"
    case lector = "LEKTORAT"
    case finalizer = "FINALIZER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lead: return "LEAD"
        case .support: return "SUPPORT"
        case .challenge: return "CHALLENGE"
        case .independent: return "SECOND OPINION"
        case .lector: return "LEKTORAT"
        case .finalizer: return "FINALIZER"
        }
    }

    var shortDescription: String {
        switch self {
        case .lead:
            return "führt den Schritt"
        case .support:
            return "ergänzt und liefert zu"
        case .challenge:
            return "prüft kritisch"
        case .independent:
            return "unabhängige Zweitmeinung"
        case .lector:
            return "vereinheitlicht Sprache"
        case .finalizer:
            return "erstellt Endartefakt"
        }
    }

    var detailedDescription: String {
        switch self {
        case .lead:
            return "LEAD bedeutet: Dieser Skill-Schritt ist primär verantwortlich. Er strukturiert das Ergebnis, trifft Annahmen transparent und liefert den Hauptoutput."
        case .support:
            return "SUPPORT bedeutet: Dieser Skill-Schritt ergänzt einen vorherigen oder führenden Schritt. Er vertieft Teilaspekte, liefert Material zu oder bereitet Übergaben vor."
        case .challenge:
            return "CHALLENGE bedeutet: Dieser Skill-Schritt prüft kritisch, sucht Lücken, Risiken, Widersprüche und Qualitätsprobleme."
        case .independent:
            return "SECOND OPINION bedeutet: Dieser Skill-Schritt erstellt bewusst eine unabhängige Zweitmeinung, ohne die vorherige Sicht einfach zu übernehmen."
        case .lector:
            return "LEKTORAT bedeutet: Dieser Schritt vereinheitlicht Sprache, Struktur, Tonalität und Lesbarkeit, ohne fachliche Aussagen unnötig zu verändern."
        case .finalizer:
            return "FINALIZER bedeutet: Dieser Schritt erzeugt aus allen freigegebenen Vorarbeiten das finale Artefakt, zum Beispiel Entscheidungsvorlage, Management Summary oder Folienstruktur."
        }
    }

    var promptInstruction: String {
        switch self {
        case .lead:
            return "Rollenverhalten LEAD: Erzeuge den maßgeblichen Hauptoutput dieses Schritts. Strukturiere klar, triff Annahmen transparent und liefere ein vollständiges Arbeitsartefakt."
        case .support:
            return "Rollenverhalten SUPPORT: Nutze die vorherigen aktuellen Artefakte, ergänze und korrigiere sie gezielt. Schreibe nicht grundlos alles neu, sondern liefere Mehrwert, fehlende Aspekte und konkrete Ergänzungen."
        case .challenge:
            return "Rollenverhalten CHALLENGE: Prüfe kritisch. Suche Widersprüche, fehlende Belege, Risiken, Auslassungen, Prompt- oder Denkfehler. Liefere klare Befunde und Verbesserungen."
        case .independent:
            return "Rollenverhalten SECOND OPINION: Erstelle eine eigenständige Zweitmeinung. Nutze Input und Vorartefakte als Kontext, aber übernimm deren Schlussfolgerungen nicht ungeprüft."
        case .lector:
            return "Rollenverhalten LEKTORAT: Vereinheitliche Sprache, Struktur, Tonalität und Anschlussfähigkeit. Verändere fachliche Aussagen nur, wenn sie unklar, widersprüchlich oder unbelegt sind."
        case .finalizer:
            return "Rollenverhalten FINALIZER: Erzeuge das finale Ergebnis aus den freigegebenen aktuellen Artefakten. Verdichte, priorisiere und liefere ein nutzbares Endartefakt."
        }
    }
}

enum WorkflowMode: String, Codable, CaseIterable, Identifiable {
    case execute
    case edit
    case audit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .execute: return "Ausführen"
        case .edit: return "Bearbeiten"
        case .audit: return "Prüfen"
        }
    }

    var description: String {
        switch self {
        case .execute: return "Daten eingeben, Ablauf starten, Ergebnisse freigeben oder Feedback geben."
        case .edit: return "Ablauf aus Blöcken bauen, sortieren und je Block Prüfung einstellen."
        case .audit: return "Nachsehen, welche Eingaben, Prompts, Ergebnisse und Nachweise entstanden sind."
        }
    }
}

enum QualityGateMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case auto
    case required
    case none

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .manual:
            return "Manual: Der Ablauf hält nach diesem Block an, du prüfst das Ergebnis und gibst es frei oder schickst es mit Feedback zurück."
        case .required:
            return "Required: Wie Manual, aber als bewusst zwingende Freigabe markiert, weil dieser Block nicht übersprungen werden soll."
        case .auto:
            return "Auto: Die App lässt das Ergebnis automatisch durch QS prüfen und hält nur an, wenn Nacharbeit nötig ist."
        case .none:
            return "None: Der Ablauf läuft ohne Prüfung direkt zum nächsten Block weiter."
        }
    }
}

enum StepInputMode: String, Codable, CaseIterable, Identifiable {
    case sourceOnly
    case previous
    case allPrevious
    case selectedSteps

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sourceOnly: return "Source only"
        case .previous: return "Previous"
        case .allPrevious: return "All previous"
        case .selectedSteps: return "Selected"
        }
    }

    var explanation: String {
        switch self {
        case .sourceOnly:
            return "Nutzt nur Source, Auftrag und Datenkontext. Dieser Knoten kann parallel zu anderen Source-only-Knoten laufen."
        case .previous:
            return "Nutzt den direkt vorherigen Knoten. Das ist die klassische lineare Pipe."
        case .allPrevious:
            return "Nutzt alle vorherigen gültigen Artefakte. Geeignet für Synthese, Abschlussbericht oder Lektorat."
        case .selectedSteps:
            return "Nutzt nur explizit ausgewählte Vorgängerknoten. Damit kann Knoten 5 gezielt nur Knoten 1 lesen."
        }
    }
}

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic

    var id: String { rawValue }
    var label: String { self == .openAI ? "OpenAI" : "Anthropic" }
}

enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
}

struct WorkflowInput: Codable, Hashable {
    var folderPath: String = ""
    var goal: String = ""
    var context: String = ""
    var desiredResult: String = ""
    var criteria: String = ""
    var prompt: String = ""

    enum CodingKeys: String, CodingKey {
        case folderPath
        case goal
        case context
        case desiredResult
        case criteria
        case prompt
    }

    init(
        folderPath: String = "",
        goal: String = "",
        context: String = "",
        desiredResult: String = "",
        criteria: String = "",
        prompt: String = ""
    ) {
        self.folderPath = folderPath
        self.goal = goal
        self.context = context
        self.desiredResult = desiredResult
        self.criteria = criteria
        self.prompt = prompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath) ?? ""
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        context = try container.decodeIfPresent(String.self, forKey: .context) ?? ""
        desiredResult = try container.decodeIfPresent(String.self, forKey: .desiredResult) ?? ""
        criteria = try container.decodeIfPresent(String.self, forKey: .criteria) ?? ""
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
    }
}

struct ConsultantStep: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String = ""
    var skillId: String = ""
    var personaId: String?
    var inputMode: StepInputMode = .previous
    var inputStepIds: [String] = []
    var role: ConsultantRole = .lead
    var taskText: String = ""
    var prompt: String = ""
    var outputType: String = "markdown-report"
    var qualityGate: QualityGateMode = .manual
    var providerOverride: AIProvider?
    var modelOverride: String = ""
    var acceptanceCriteria: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case skillId
        case personaId
        case inputMode
        case inputStepIds
        case role
        case taskText
        case prompt
        case outputType
        case qualityGate
        case providerOverride
        case modelOverride
        case acceptanceCriteria
    }

    init(
        id: String = UUID().uuidString,
        title: String = "",
        skillId: String = "",
        personaId: String? = nil,
        inputMode: StepInputMode = .previous,
        inputStepIds: [String] = [],
        role: ConsultantRole = .lead,
        taskText: String = "",
        prompt: String = "",
        outputType: String = "markdown-report",
        qualityGate: QualityGateMode = .manual,
        providerOverride: AIProvider? = nil,
        modelOverride: String = "",
        acceptanceCriteria: String = ""
    ) {
        self.id = id
        self.title = title
        self.skillId = skillId
        self.personaId = personaId
        self.inputMode = inputMode
        self.inputStepIds = inputStepIds
        self.role = role
        self.taskText = taskText
        self.prompt = prompt
        self.outputType = outputType
        self.qualityGate = qualityGate
        self.providerOverride = providerOverride
        self.modelOverride = modelOverride
        self.acceptanceCriteria = acceptanceCriteria
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        skillId = try container.decodeIfPresent(String.self, forKey: .skillId) ?? ""
        personaId = try container.decodeIfPresent(String.self, forKey: .personaId)
        inputMode = try container.decodeIfPresent(StepInputMode.self, forKey: .inputMode) ?? .previous
        inputStepIds = try container.decodeIfPresent([String].self, forKey: .inputStepIds) ?? []
        role = try container.decodeIfPresent(ConsultantRole.self, forKey: .role) ?? .lead
        taskText = try container.decodeIfPresent(String.self, forKey: .taskText) ?? ""
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        outputType = try container.decodeIfPresent(String.self, forKey: .outputType) ?? "markdown-report"
        qualityGate = try container.decodeIfPresent(QualityGateMode.self, forKey: .qualityGate) ?? .manual
        providerOverride = try container.decodeIfPresent(AIProvider.self, forKey: .providerOverride)
        modelOverride = try container.decodeIfPresent(String.self, forKey: .modelOverride) ?? ""
        acceptanceCriteria = try container.decodeIfPresent(String.self, forKey: .acceptanceCriteria) ?? ""
    }
}

struct ShortcutWorkflow: Identifiable, Codable, Hashable {
    var id: String = "wf-\(UUID().uuidString)"
    var name: String = "Neuer Ablauf"
    var input: WorkflowInput = WorkflowInput()
    var provider: AIProvider = .openAI
    var steps: [ConsultantStep] = []
}

extension ShortcutWorkflow {
    func dependencyIndices(for index: Int) -> [Int] {
        guard steps.indices.contains(index) else { return [] }
        let step = steps[index]
        switch step.inputMode {
        case .sourceOnly:
            return []
        case .previous:
            return index > 0 ? [index - 1] : []
        case .allPrevious:
            return index > 0 ? Array(0..<index) : []
        case .selectedSteps:
            let selected = Set(step.inputStepIds)
            return steps[..<index].indices.filter { selected.contains(steps[$0].id) }
        }
    }

    func transitiveDependentIndices(of sourceIndex: Int) -> [Int] {
        guard steps.indices.contains(sourceIndex) else { return [] }
        var result: Set<Int> = []
        var stack = [sourceIndex]
        while let current = stack.popLast() {
            for index in steps.indices where index > current {
                guard dependencyIndices(for: index).contains(current), !result.contains(index) else { continue }
                result.insert(index)
                stack.append(index)
            }
        }
        return result.sorted()
    }

    func executionLevels() -> [[Int]] {
        guard !steps.isEmpty else { return [] }
        var levelsByIndex: [Int: Int] = [:]
        for index in steps.indices {
            let dependencies = dependencyIndices(for: index)
            let level = dependencies
                .compactMap { levelsByIndex[$0] }
                .max()
                .map { $0 + 1 } ?? 0
            levelsByIndex[index] = level
        }
        let maxLevel = levelsByIndex.values.max() ?? 0
        return (0...maxLevel).map { level in
            steps.indices.filter { levelsByIndex[$0] == level }
        }
    }
}

enum RunStatus: String, Codable {
    case idle
    case pending
    case running
    case needsReview
    case approved
    case done
    case failed
}

struct RunStepState: Identifiable, Codable, Hashable {
    var id: String
    var index: Int
    var title: String
    var status: RunStatus = .pending
    var attempt: Int = 0
    var currentArtifactPath: String = ""
    var output: String = ""
    var qualityReport: String = ""
    var feedback: String = ""
    var error: String = ""
}

struct StepArtifact: Hashable {
    var title: String
    var path: String
    var content: String
}

struct StepDebugSnapshot: Hashable {
    var stepTitle: String
    var attempt: Int
    var stepDirectoryPath: String
    var attemptDirectoryPath: String
    var files: [DebugFileSnapshot]
}

struct DebugFileSnapshot: Identifiable, Hashable {
    var id: String { path }
    var phase: String
    var title: String
    var path: String
    var contentPreview: String
    var characterCount: Int
    var isTruncated: Bool
}

struct AuditChainSummary: Hashable {
    var exists: Bool = false
    var isValid: Bool = false
    var isSealed: Bool = false
    var entryCount: Int = 0
    var lastEvent: String = ""
    var finalHash: String = ""
    var message: String = "Keine Audit-Chain vorhanden."
}

enum GatekeeperSeverity: String, Codable, Hashable {
    case ok = "OK"
    case warning = "WARNUNG"
    case critical = "KRITISCH"
}

struct GatekeeperIssue: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var severity: GatekeeperSeverity
    var title: String
    var detail: String
}

struct GatekeeperReport: Codable, Hashable {
    var checkedAt: String = ""
    var overall: GatekeeperSeverity = .ok
    var summary: String = "Noch nicht geprüft."
    var issues: [GatekeeperIssue] = []
}

struct PromptPreview: Hashable {
    var stepID: String?
    var system: String = ""
    var user: String = ""
    var skillTitle: String = ""
    var personaTitle: String = ""

    var isEmpty: Bool {
        system.trimmed.isEmpty && user.trimmed.isEmpty
    }
}
