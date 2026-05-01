import Foundation

enum ConsultantRole: String, Codable, CaseIterable, Identifiable {
    case lead = "LEAD"
    case support = "SUPPORT"
    case challenge = "CHALLENGE"
    case independent = "INDEPENDENT"

    var id: String { rawValue }

    var shortDescription: String {
        switch self {
        case .lead:
            return "führt den Schritt"
        case .support:
            return "ergänzt und liefert zu"
        case .challenge:
            return "prüft kritisch"
        case .independent:
            return "arbeitet unabhängig"
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
            return "INDEPENDENT bedeutet: Dieser Berater arbeitet bewusst eigenständig, ohne die Sicht des Lead-Schritts einfach zu übernehmen."
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
    var prompt: String = ""
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
