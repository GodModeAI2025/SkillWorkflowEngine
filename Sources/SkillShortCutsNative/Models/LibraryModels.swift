import Foundation

enum LibraryItemKind: String, Codable, CaseIterable, Identifiable {
    case rootSkill
    case consultingAgent
    case jobSkill
    case personaSkill
    case qualityGate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rootSkill: return "Root"
        case .consultingAgent: return "Agent"
        case .jobSkill: return "WAS"
        case .personaSkill: return "WER"
        case .qualityGate: return "QS"
        }
    }
}

struct LibraryItem: Identifiable, Codable, Hashable {
    var id: String
    var kind: LibraryItemKind
    var name: String
    var title: String
    var summary: String
    var filePath: String
    var tags: [String]
    var content: String

    var displayName: String {
        if kind == .personaSkill && title != name {
            let value = title
                .replacingOccurrences(of: "Persona:", with: "")
                .trimmed
            return value.isEmpty ? title : value
        }

        let value = name
            .replacingOccurrences(of: "persona-", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .trimmed
        return value.isEmpty ? title : value
    }

    var dragPayload: String {
        switch kind {
        case .personaSkill:
            return "persona:\(id)"
        default:
            return "skill:\(id)"
        }
    }
}

struct ConsultantLibrary {
    var sourcePath: String
    var items: [LibraryItem]
    var templates: [WorkflowTemplate]

    var rootSkill: LibraryItem? {
        items.first { $0.kind == .rootSkill }
    }

    var lector: LibraryItem? {
        items.first { $0.id == "agent:lektor" }
    }

    var personas: [LibraryItem] {
        items.filter { $0.kind == .personaSkill }
    }

    var skills: [LibraryItem] {
        items.filter { $0.kind != .personaSkill && $0.kind != .rootSkill }
    }
}

struct WorkflowTemplate: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var when: String
    var steps: [TemplateStep]
}

struct TemplateStep: Codable, Hashable {
    var stage: String
    var persona: String
    var task: String
}
