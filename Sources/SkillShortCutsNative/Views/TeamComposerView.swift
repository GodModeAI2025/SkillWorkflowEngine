import SwiftUI
import UniformTypeIdentifiers

struct TeamComposerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 18) {
                    if store.workflow.steps.isEmpty {
                        emptyDropZone
                    } else {
                        ForEach(Array(store.workflow.steps.enumerated()), id: \.element.id) { index, step in
                            ConsultantCard(index: index, step: step)
                        }
                        addDropZone
                    }
                }
                .padding(22)
            }
            .background(ScratchStyle.workspaceBackground)
            .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
                loadPayload(from: providers) { payload in
                    store.handleDrop(payload: payload)
                }
            }
        }
        .background(ScratchStyle.workspaceBackground)
    }

    private var header: some View {
        HStack {
            ScratchStyle.headerNumber(2, color: Color.nwebTextSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Ablauf")
                    .font(.nwebTitle)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text("Ziehe Blöcke von links hierher. SkillShortCuts arbeitet sie später von oben nach unten ab.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            Spacer()
            Text("\(store.workflow.steps.count) Blöcke")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nwebOrange.opacity(0.12), in: Capsule())
        }
        .padding(20)
        .background(ScratchStyle.stageBackground)
    }

    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece")
                .font(.system(size: 36))
                .foregroundStyle(ScratchStyle.looksPurple)
            Text("WAS-Block hierher ziehen")
                .font(.headline)
                .foregroundStyle(Color.nwebTextPrimary)
            Text("Starte mit dem, was passieren soll. Perspektive und Prüfung kannst du danach ergänzen.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(isDropTarget ? ScratchStyle.looksPurple.opacity(0.16) : Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: ScratchStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ScratchStyle.panelRadius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(isDropTarget ? ScratchStyle.looksPurple : Color.nwebBorder)
        )
    }

    private var addDropZone: some View {
        HStack {
            Text("von oben nach unten")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.nwebTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nwebTextSecondary.opacity(0.10), in: Capsule())

            Spacer()

            Image(systemName: "plus.circle")
            Text("Weiteren WAS-Block hier ablegen")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.nwebTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: ScratchStyle.blockRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
                .stroke(Color.nwebBorder)
        )
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
        let blockColor = skill.map { ScratchStyle.blockColor(for: $0.kind) } ?? ScratchStyle.looksPurple
        Button {
            store.selectStep(step.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(blockColor, in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(step.title.isEmpty ? (skill?.displayName ?? "Unbenannter Block") : step.title)
                                .font(.headline)
                                .foregroundStyle(Color.nwebTextPrimary)
                                .lineLimit(1)

                            if isRunning {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                    .scaleEffect(0.72)
                                    .frame(width: 14, height: 14)
                                    .help("Skill läuft")
                            }

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

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
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
                        Label(step.role.displayName, systemImage: "flag.checkered")
                            .foregroundStyle(Color.nwebTextSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.nwebTextSecondary.opacity(0.10), in: Capsule())

                        Label("QS \(step.qualityGate.rawValue)", systemImage: "checkmark.seal")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
                }

                HStack(spacing: 8) {
                    Chip(
                        title: "WAS",
                        value: skill?.displayName ?? "Skill fehlt",
                        systemImage: "briefcase",
                        color: blockColor
                    )
                    Chip(
                        title: "WER",
                        value: persona?.displayName ?? "Persona optional",
                        systemImage: "person.crop.circle",
                        color: ScratchStyle.variablesOrange
                    )
                }
            }
            .padding(18)
            .padding(.leading, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scratchBlock(
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
            return ScratchStyle.looksPurple.opacity(0.13)
        }
        return Color.clear
    }

    private func cardBorder(isWaitingForReview: Bool) -> some View {
        RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
            .stroke(borderColor(isWaitingForReview: isWaitingForReview), lineWidth: borderWidth(isWaitingForReview: isWaitingForReview))
            .overlay {
                if isWaitingForReview {
                    RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
                        .stroke(Color.nwebOrange.opacity(glowPulse ? 0.75 : 0.28), lineWidth: glowPulse ? 5 : 2)
                        .blur(radius: glowPulse ? 7 : 3)
                }
            }
    }

    private func borderColor(isWaitingForReview: Bool) -> Color {
        if isWaitingForReview { return .nwebOrange }
        if store.selectedStepID == step.id { return .nwebAccent }
        return .nwebBorder
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
