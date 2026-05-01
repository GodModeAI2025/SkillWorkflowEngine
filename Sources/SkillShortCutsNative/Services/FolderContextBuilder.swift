import Foundation

struct FolderContextBuilder {
    func build(folderPath: String, maxCharacters: Int = 70_000) -> String {
        guard !folderPath.trimmed.isEmpty else {
            return "Kein Ordner angegeben."
        }

        let root = URL(fileURLWithPath: folderPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: root.path) else {
            return "Ordner nicht gefunden: \(root.path)"
        }

        var entries: [URL] = []
        collect(url: root, root: root, output: &entries, depth: 0)

        let tree = entries
            .prefix(700)
            .map { url -> String in
                let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                return "\(isDirectory ? "d" : "f") \(rel)"
            }
            .joined(separator: "\n")

        var remaining = maxCharacters
        var snippets: [String] = []
        for url in entries where remaining > 0 && isReadableTextFile(url) {
            guard let data = try? Data(contentsOf: url),
                  data.count < 220_000,
                  let text = String(data: data, encoding: .utf8)
            else { continue }
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let chunk = text.limited(to: min(remaining, 12_000))
            snippets.append("## \(rel)\n```\n\(chunk)\n```")
            remaining -= chunk.count
        }

        return """
        Root: \(root.path)

        # Dateibaum
        \(tree)

        # Dateiauszuege
        \(snippets.joined(separator: "\n\n"))
        """
    }

    private func collect(url: URL, root: URL, output: inout [URL], depth: Int) {
        guard depth <= 6, output.count < 900 else { return }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if shouldSkip(child.lastPathComponent) { continue }
            output.append(child)
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                collect(url: child, root: root, output: &output, depth: depth + 1)
            }
        }
    }

    private func shouldSkip(_ name: String) -> Bool {
        [".git", "node_modules", "dist", "build", ".next", ".cache", "DerivedData", "target", ".venv"].contains(name)
    }

    private func isReadableTextFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "txt", "json", "yaml", "yml", "ts", "tsx", "js", "jsx", "css", "html", "swift", "py", "java", "kt", "go", "rs", "rb", "sh", "sql", "xml"].contains(ext)
    }
}
