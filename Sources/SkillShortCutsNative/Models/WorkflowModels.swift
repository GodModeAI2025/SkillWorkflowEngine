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
            return "LEAD bedeutet: Dieser Berater ist primär verantwortlich für den Schritt. Er strukturiert das Ergebnis, trifft Annahmen transparent und liefert den Hauptoutput."
        case .support:
            return "SUPPORT bedeutet: Dieser Berater ergänzt einen vorherigen oder führenden Schritt. Er vertieft Teilaspekte, liefert Material zu oder bereitet Übergaben vor."
        case .challenge:
            return "CHALLENGE bedeutet: Dieser Berater prüft kritisch, sucht Lücken, Risiken, Widersprüche und Qualitätsprobleme."
        case .independent:
            return "SECOND OPINION bedeutet: Dieser Berater erstellt bewusst eine unabhängige Zweitmeinung, ohne die vorherige Sicht einfach zu übernehmen."
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
        case .execute: return "Input geben, Workflow starten, QS freigeben und Feedback geben."
        case .edit: return "Skillworkflow, Rollen, Reihenfolge, Modelle und QS konfigurieren."
        case .audit: return "Run-Verzeichnis, Artefakte, Gatekeeper, Hashes und Nachweise prüfen."
        }
    }
}

enum QualityGateMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case auto
    case required
    case none

    var id: String { rawValue }
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
    var role: ConsultantRole = .lead
    var taskText: String = ""
    var prompt: String = ""
    var outputType: String = "markdown-report"
    var qualityGate: QualityGateMode = .manual
    var providerOverride: AIProvider?
    var modelOverride: String = ""
    var acceptanceCriteria: String = ""
}

struct ShortcutWorkflow: Identifiable, Codable, Hashable {
    var id: String = "wf-\(UUID().uuidString)"
    var name: String = "Neuer Beratungsworkflow"
    var input: WorkflowInput = WorkflowInput()
    var provider: AIProvider = .openAI
    var steps: [ConsultantStep] = []
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
