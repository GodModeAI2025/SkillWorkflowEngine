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
                LazyVStack(spacing: 12) {
                    if store.workflow.steps.isEmpty {
                        emptyDropZone
                    } else {
                        ForEach(Array(store.workflow.steps.enumerated()), id: \.element.id) { index, step in
                            ConsultantCard(index: index, step: step)
                        }
                        addDropZone
                    }
                }
                .padding(16)
            }
            .background(Color.nwebBackgroundSecondary)
            .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
                loadPayload(from: providers) { payload in
                    store.handleDrop(payload: payload)
                }
            }
        }
        .background(Color.nwebBackgroundPrimary)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Beraterteam")
                    .font(.nwebTitle)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text("Kombiniere WER + WAS + Daten zu einem ausführbaren Beratungsworkflow.")
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
            }
            Spacer()
            Text("\(store.workflow.steps.count) Schritte")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nwebAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nwebOrange.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .background(Color.nwebBackgroundPrimary)
    }

    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 36))
                .foregroundStyle(Color.nwebOrange)
            Text("WAS-Skill hierher ziehen")
                .font(.headline)
                .foregroundStyle(Color.nwebTextPrimary)
            Text("Danach WER-Persona auf den Berater-Slot ziehen.")
                .font(.caption)
                .foregroundStyle(Color.nwebTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(isDropTarget ? Color.nwebOrange.opacity(0.14) : Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.mediumRadius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(isDropTarget ? Color.nwebOrange : Color.nwebBorder)
        )
    }

    private var addDropZone: some View {
        HStack {
            Image(systemName: "plus.circle")
            Text("Weiteren WAS-Skill hier ablegen")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.nwebTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NWEBTheme.mediumRadius)
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
        Button {
            store.selectStep(step.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.nwebAccent, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(step.title.isEmpty ? (skill?.displayName ?? "Unbenannter Schritt") : step.title)
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

                    VStack(alignment: .trailing, spacing: 6) {
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
                        Label(step.role.displayName, systemImage: "person.badge.key")
                        Label("QS \(step.qualityGate.rawValue)", systemImage: "checkmark.seal")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nwebTextSecondary)
                }

                HStack(spacing: 8) {
                    Chip(title: "WAS", value: skill?.displayName ?? "Skill fehlt", systemImage: "briefcase")
                    Chip(title: "WER", value: persona?.displayName ?? "Persona optional", systemImage: "person.crop.circle")
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            return Color.nwebOrange.opacity(0.13)
        }
        return Color.nwebBackgroundPrimary
    }

    private func cardBorder(isWaitingForReview: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(borderColor(isWaitingForReview: isWaitingForReview), lineWidth: borderWidth(isWaitingForReview: isWaitingForReview))
            .overlay {
                if isWaitingForReview {
                    RoundedRectangle(cornerRadius: 12)
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(title == "WER" ? Color.nwebOrange : Color.nwebAccent)
            Text(title)
                .foregroundStyle(Color.nwebTextSecondary)
            Text(value)
                .foregroundStyle(Color.nwebTextPrimary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.nwebBackgroundSecondary, in: Capsule())
        .overlay(Capsule().stroke(Color.nwebBorder))
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
