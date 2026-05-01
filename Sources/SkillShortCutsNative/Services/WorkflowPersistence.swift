import Foundation

struct WorkflowPersistence {
    private var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SkillShortCuts/Workflows", isDirectory: true)
    }

    func save(_ workflow: ShortcutWorkflow) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("\(workflow.id).skillshortcut.json")
        let data = try JSONEncoder.pretty.encode(workflow)
        try data.write(to: url, options: [.atomic])
    }

    func loadAll() -> [ShortcutWorkflow] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ShortcutWorkflow.self, from: data)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
