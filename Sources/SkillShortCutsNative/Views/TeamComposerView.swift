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
            .background(Color.enbwBackgroundSecondary)
            .onDrop(of: [.plainText], isTargeted: $isDropTarget) { providers in
                loadPayload(from: providers) { payload in
                    store.handleDrop(payload: payload)
                }
            }
        }
        .background(Color.enbwBackgroundPrimary)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Beraterteam")
                    .font(.enbwTitle)
                    .foregroundStyle(Color.enbwTextPrimary)
                Text("Kombiniere WER + WAS + Daten zu einem ausführbaren Beratungsworkflow.")
                    .font(.caption)
                    .foregroundStyle(Color.enbwTextSecondary)
            }
            Spacer()
            Text("\(store.workflow.steps.count) Schritte")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.enbwAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.enbwOrange.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .background(Color.enbwBackgroundPrimary)
    }

    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 36))
                .foregroundStyle(Color.enbwOrange)
            Text("WAS-Skill hierher ziehen")
                .font(.headline)
                .foregroundStyle(Color.enbwTextPrimary)
            Text("Danach WER-Persona auf den Berater-Slot ziehen.")
                .font(.caption)
                .foregroundStyle(Color.enbwTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(isDropTarget ? Color.enbwOrange.opacity(0.14) : Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(isDropTarget ? Color.enbwOrange : Color.enbwBorder)
        )
    }

    private var addDropZone: some View {
        HStack {
            Image(systemName: "plus.circle")
            Text("Weiteren WAS-Skill hier ablegen")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.enbwTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EnBWTheme.mediumRadius)
                .stroke(Color.enbwBorder)
        )
    }
}

struct ConsultantCard: View {
    @EnvironmentObject private var store: AppStore
    let index: Int
    let step: ConsultantStep
    @State private var isDropTarget = false

    var body: some View {
        let skill = store.item(id: step.skillId)
        let persona = store.item(id: step.personaId)
        let runState = store.runSteps.first { $0.id == step.id }
        let isRunning = runState?.status == .running
        Button {
            store.selectStep(step.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.enbwAccent, in: RoundedRectangle(cornerRadius: EnBWTheme.smallRadius))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(step.title.isEmpty ? (skill?.displayName ?? "Unbenannter Schritt") : step.title)
                                .font(.headline)
                                .foregroundStyle(Color.enbwTextPrimary)
                                .lineLimit(1)

                            if isRunning {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                    .scaleEffect(0.72)
                                    .frame(width: 14, height: 14)
                                    .help("Skill läuft")
                            }
                        }

                        Text(step.taskText.isEmpty ? (skill?.summary ?? "") : step.taskText)
                            .font(.caption)
                            .foregroundStyle(Color.enbwTextSecondary)
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
                            .foregroundStyle(runState.status == .failed ? Color.enbwError : Color.enbwTextSecondary)
                        }
                        Label(step.role.rawValue, systemImage: "person.badge.key")
                        Label("QS \(step.qualityGate.rawValue)", systemImage: "checkmark.seal")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.enbwTextSecondary)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(store.selectedStepID == step.id ? Color.enbwAccent : Color.enbwBorder, lineWidth: store.selectedStepID == step.id ? 2 : 1)
        )
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
            return Color.enbwOrange.opacity(0.13)
        }
        return Color.enbwBackgroundPrimary
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
                .foregroundStyle(title == "WER" ? Color.enbwOrange : Color.enbwAccent)
            Text(title)
                .foregroundStyle(Color.enbwTextSecondary)
            Text(value)
                .foregroundStyle(Color.enbwTextPrimary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.enbwBackgroundSecondary, in: Capsule())
        .overlay(Capsule().stroke(Color.enbwBorder))
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
