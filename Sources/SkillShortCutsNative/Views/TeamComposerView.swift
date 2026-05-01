import SwiftUI
import UniformTypeIdentifiers

struct TeamComposerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isDropTarget = false

    var body: some View {
        let graph = PipeCanvasGraph(workflow: store.workflow)

        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 18) {
                    if store.workflow.steps.isEmpty {
                        emptyDropZone
                    } else {
                        PipeSourceStub()

                        ForEach(Array(graph.levels.enumerated()), id: \.offset) { levelIndex, level in
                            PipeLevelConnector(level: levelIndex, parallelCount: level.count)
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(level, id: \.step.id) { node in
                                    ConsultantCard(index: node.index, step: node.step)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        PipeOutputNode(runComplete: pipeOutputIsComplete)
                        addDropZone
                    }
                }
                .padding(22)
            }
            .background(canvasBackground)
            .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
                loadPayload(from: providers) { payload in
                    store.handleDrop(payload: payload)
                }
            }
        }
        .background(PipesStyle.canvasBackground)
    }

    private var header: some View {
        PipePaneHeader(
            number: 2,
            title: "Pipe Canvas",
            subtitle: "Module sind über Pipes verbunden. Daten fließen von Source über Operatoren bis zum Output.",
            color: PipesStyle.outputTeal,
            trailing: "\(store.workflow.steps.count) Module"
        )
    }

    private var pipeOutputIsComplete: Bool {
        !store.runSteps.isEmpty && store.runSteps.allSatisfy { statusIsOutputComplete($0.status) }
    }

    private var emptyDropZone: some View {
        VStack(spacing: 18) {
            PipeSourceStub()

            PipeConnector(active: isDropTarget, color: PipesStyle.operatorPurple)

            VStack(spacing: 10) {
                PipePort(color: PipesStyle.operatorPurple, filled: false)
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 34))
                    .foregroundStyle(PipesStyle.operatorPurple)
                Text("Operator-Modul hierher ziehen")
                    .font(.headline)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text("Starte mit einem WAS-Modul. Persona, QS und Redo bleiben pro Modul konfigurierbar.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .pipePanel(color: PipesStyle.operatorPurple, emphasized: isDropTarget)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var addDropZone: some View {
        HStack {
            Text("append pipe")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nwebTextSecondary.opacity(0.10), in: Capsule())

            Spacer()

            Image(systemName: "plus.circle")
            Text("Weiteres Operator-Modul hier ablegen")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.nwebTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(PipesStyle.moduleFill, in: RoundedRectangle(cornerRadius: PipesStyle.moduleRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PipesStyle.moduleRadius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundStyle(isDropTarget ? PipesStyle.operatorPurple : Color.nwebBorder)
        )
    }

    private var canvasBackground: some View {
        ZStack {
            PipesStyle.canvasBackground
            Canvas { context, size in
                let spacing: CGFloat = 32
                var path = Path()
                var x: CGFloat = 0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(Color.nwebBorder.opacity(0.24)), lineWidth: 0.6)
            }
        }
    }

}

private struct PipeCanvasGraph {
    let levels: [[(index: Int, step: ConsultantStep)]]

    init(workflow: ShortcutWorkflow) {
        levels = workflow.executionLevels().map { level in
            level.map { index in
                (index: index, step: workflow.steps[index])
            }
        }
    }
}

private struct PipeLevelConnector: View {
    let level: Int
    let parallelCount: Int

    var body: some View {
        VStack(spacing: 6) {
            PipeConnector(active: false, color: PipesStyle.pipeLine)
            HStack(spacing: 8) {
                Text(level == 0 ? "Source feeds modules" : "join / continue")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
                if parallelCount > 1 {
                    Text("\(parallelCount) parallel")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PipesStyle.outputTeal)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PipesStyle.outputTeal.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

private struct PipeSourceStub: View {
    var body: some View {
        HStack(spacing: 10) {
            PipePort(color: PipesStyle.sourceBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PipesStyle.sourceBlue)
                Text("Auftrag, Datenordner, Kontext")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            Spacer()
            Image(systemName: "tray.full")
                .foregroundStyle(PipesStyle.sourceBlue)
        }
        .padding(14)
        .pipeModule(color: PipesStyle.sourceBlue)
    }
}

private struct PipeOutputNode: View {
    let runComplete: Bool

    var body: some View {
        VStack(spacing: 12) {
            PipeConnector(active: runComplete, color: PipesStyle.outputTeal)
            HStack(spacing: 10) {
                PipePort(color: PipesStyle.outputTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pipe Output")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PipesStyle.outputTeal)
                    Text("current.md, Audit-Chain, Debug-Dateien")
                        .font(.caption)
                        .foregroundStyle(Color.nwebTextSecondary)
                }
                Spacer()
                Image(systemName: "shippingbox")
                    .foregroundStyle(PipesStyle.outputTeal)
            }
            .padding(14)
            .pipeModule(color: PipesStyle.outputTeal, active: runComplete)
        }
    }
}

struct ConsultantCard: View {
    @EnvironmentObject private var store: AppStore
    let index: Int
    let step: ConsultantStep
    @State private var isDropTarget = false
    @State private var glowPulse = false

    var body: some View {
        let skill = store.item(id: step.skillId)
        let persona = store.item(id: step.personaId)
        let runState = store.runSteps.first { $0.id == step.id }
        let isRunning = runState?.status == .running
        let isWaitingForReview = runState?.status == .needsReview
        let blockColor = skill.map { PipesStyle.moduleColor(for: $0.kind) } ?? PipesStyle.operatorPurple
        Button {
            store.selectStep(step.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    PipePort(color: blockColor)

                    Text("MODULE \(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(blockColor)

                    Spacer()

                    if isRunning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .scaleEffect(0.72)
                            .frame(width: 14, height: 14)
                            .help("Modul läuft")
                    }

                    Text(step.role.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.nwebTextSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.nwebTextSecondary.opacity(0.10), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(PipesStyle.moduleHeader)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(step.title.isEmpty ? (skill?.displayName ?? "Unbenanntes Modul") : step.title)
                                .font(.headline)
                                .foregroundStyle(Color.nwebTextPrimary)
                                .lineLimit(1)

                            if isWaitingForReview {
                                Label("wartet auf QS", systemImage: "hourglass")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.nwebOrange)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.nwebOrange.opacity(0.14), in: Capsule())
                                    .help("Dieser Schritt wartet auf Freigabe oder Redo")
                            }
                        }

                        Text(step.taskText.isEmpty ? (skill?.summary ?? "") : step.taskText)
                            .font(.caption)
                            .foregroundStyle(Color.nwebTextSecondary)
                            .lineLimit(2)
                    }

                    PipeInputSummary(
                        mode: step.inputMode,
                        dependencies: dependencyLabels(for: index)
                    )

                    HStack(spacing: 8) {
                        Chip(
                            title: "OPERATOR",
                            value: skill?.displayName ?? "Skill fehlt",
                            systemImage: "square.stack.3d.up",
                            color: blockColor
                        )
                        Chip(
                            title: "PERSONA",
                            value: persona?.displayName ?? "optional",
                            systemImage: "person.crop.circle",
                            color: PipesStyle.personaOrange
                        )
                    }

                    HStack(spacing: 8) {
                        if let runState, runState.status != .pending {
                            HStack(spacing: 5) {
                                if runState.status == .running {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                        .scaleEffect(0.65)
                                        .frame(width: 12, height: 12)
                                }
                                Text(runState.status.processLabel)
                            }
                            .foregroundStyle(runState.status == .failed ? Color.nwebError : Color.nwebTextSecondary)
                        }

                        Label("QS \(step.qualityGate.rawValue)", systemImage: "checkmark.seal")
                        Spacer()
                        PipePort(color: blockColor)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
                }
                .padding(16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pipeModule(
            color: blockColor,
            selected: store.selectedStepID == step.id || isWaitingForReview,
            active: isRunning || isWaitingForReview || isDropTarget
        )
        .background(background)
        .overlay(cardBorder(isWaitingForReview: isWaitingForReview))
        .shadow(
            color: isWaitingForReview ? Color.nwebOrange.opacity(glowPulse ? 0.42 : 0.18) : .clear,
            radius: isWaitingForReview ? (glowPulse ? 18 : 7) : 0,
            x: 0,
            y: 0
        )
        .onAppear {
            updateGlow(isWaiting: isWaitingForReview)
        }
        .onChange(of: isWaitingForReview) { _, newValue in
            updateGlow(isWaiting: newValue)
        }
        .onDrag {
            NSItemProvider(object: "step:\(step.id)" as NSString)
        }
        .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
            loadPayload(from: providers) { payload in
                store.handleDrop(payload: payload, targetStepID: step.id)
            }
        }
        .contextMenu {
            Button("Duplizieren") {
                store.selectStep(step.id)
                store.duplicateSelectedStep()
            }
            Button("Entfernen", role: .destructive) {
                store.selectStep(step.id)
                store.deleteSelectedStep()
            }
        }
    }

    private var background: some ShapeStyle {
        if isDropTarget {
            return PipesStyle.operatorPurple.opacity(0.13)
        }
        return Color.clear
    }

    private func cardBorder(isWaitingForReview: Bool) -> some View {
        RoundedRectangle(cornerRadius: PipesStyle.moduleRadius)
            .stroke(borderColor(isWaitingForReview: isWaitingForReview), lineWidth: borderWidth(isWaitingForReview: isWaitingForReview))
            .overlay {
                if isWaitingForReview {
                    RoundedRectangle(cornerRadius: PipesStyle.moduleRadius)
                        .stroke(Color.nwebOrange.opacity(glowPulse ? 0.75 : 0.28), lineWidth: glowPulse ? 5 : 2)
                        .blur(radius: glowPulse ? 7 : 3)
                }
            }
    }

    private func borderColor(isWaitingForReview: Bool) -> Color {
        if isWaitingForReview { return .nwebOrange }
        if store.selectedStepID == step.id { return .nwebAccent }
        return Color.nwebBorder
    }

    private func borderWidth(isWaitingForReview: Bool) -> CGFloat {
        if isWaitingForReview { return 2.5 }
        return store.selectedStepID == step.id ? 2 : 1
    }

    private func updateGlow(isWaiting: Bool) {
        if isWaiting {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                glowPulse = false
            }
        }
    }

    private func dependencyLabels(for index: Int) -> [String] {
        workflowDependencyIndices(for: index).map { dependencyIndex in
            guard store.workflow.steps.indices.contains(dependencyIndex) else { return "Knoten \(dependencyIndex + 1)" }
            let title = store.workflow.steps[dependencyIndex].title
            return "\(dependencyIndex + 1). \(title.isEmpty ? "Modul" : title)"
        }
    }

    private func workflowDependencyIndices(for index: Int) -> [Int] {
        store.workflow.dependencyIndices(for: index)
    }
}

private struct PipeInputSummary: View {
    let mode: StepInputMode
    let dependencies: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .foregroundStyle(PipesStyle.sourceBlue)
                Text(mode.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PipesStyle.sourceBlue)
                Spacer()
                Text(dependencies.isEmpty ? "Source" : "\(dependencies.count) Inputs")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
            }

            if dependencies.isEmpty {
                Text("Input: Source + Auftrag + Datenkontext")
                    .font(.caption2)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(1)
            } else {
                Text("Input: \(dependencies.joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(PipesStyle.sourceBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(PipesStyle.sourceBlue.opacity(0.22))
        )
    }
}

private extension RunStatus {
    var processLabel: String {
        switch self {
        case .idle, .pending: return "Bereit"
        case .running: return "Läuft"
        case .needsReview: return "QS wartet"
        case .approved: return "Freigegeben"
        case .done: return "Fertig"
        case .failed: return "Fehler"
        }
    }
}

struct Chip: View {
    var title: String
    var value: String
    var systemImage: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .foregroundStyle(Color.nwebTextSecondary)
            Text(value)
                .foregroundStyle(Color.nwebTextPrimary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35)))
    }
}

func loadPayload(from providers: [NSItemProvider], _ action: @escaping (String) -> Void) -> Bool {
    guard let provider = providers.first else { return false }
    provider.loadObject(ofClass: NSString.self) { object, _ in
        guard let payload = object as? String else { return }
        DispatchQueue.main.async {
            action(payload)
        }
    }
    return true
}

private func statusIsOutputComplete(_ status: RunStatus) -> Bool {
    switch status {
    case .approved, .done:
        return true
    case .idle, .pending, .running, .needsReview, .failed:
        return false
    }
}
