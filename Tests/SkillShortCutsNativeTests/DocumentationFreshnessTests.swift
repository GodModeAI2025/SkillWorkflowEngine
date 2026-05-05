import XCTest

final class DocumentationFreshnessTests: XCTestCase {
    func testReadmeAndLandingPageMentionCurrentRuntimeCapabilities() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let index = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)

        for required in [
            "Erklärfunktion",
            "Erneut mit gleichem Inhalt starten",
            "LLMCompleting",
            "14 Tests",
            "docs/adr",
            "Selected",
            "Gatekeeper"
        ] {
            XCTAssertTrue(readme.contains(required), "README fehlt: \(required)")
        }

        for required in [
            "Erklärfunktion",
            "Erneut starten",
            "14 automatisierte Tests",
            "Architecture Decision Records"
        ] {
            XCTAssertTrue(index.contains(required), "index.html fehlt: \(required)")
        }
    }

    func testAdrFolderDocumentsAcceptedRuntimeDecisions() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let adrRoot = root.appendingPathComponent("docs/adr", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: adrRoot, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertGreaterThanOrEqual(files.count, 4)

        let combined = try files
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n\n")

        for required in [
            "Status: Akzeptiert",
            "NWEB",
            "Audit-Chain",
            "Pipe-Graph",
            "Erklärfunktion",
            "Testbarer Runner"
        ] {
            XCTAssertTrue(combined.contains(required), "ADRs fehlen: \(required)")
        }
    }
}
