import SwiftUI

enum PipesStyle {
    static let moduleRadius: CGFloat = 7
    static let panelRadius: CGFloat = 8

    static let canvasBackground = Color.dynamic(light: 0xE9EEF3, dark: 0x171B1F)
    static let paneBackground = Color.dynamic(light: 0xF6F7F8, dark: 0x202326)
    static let debuggerBackground = Color.dynamic(light: 0xF8F5F1, dark: 0x211E1B)
    static let moduleFill = Color.dynamic(light: 0xFFFFFF, dark: 0x292D31)
    static let moduleHeader = Color.dynamic(light: 0xEEF2F6, dark: 0x343A40)
    static let pipeLine = Color.dynamic(light: 0x7D8B99, dark: 0x92A1AF)
    static let portFill = Color.dynamic(light: 0x334455, dark: 0xD7DEE6)

    static let sourceBlue = Color.dynamic(light: 0x2F7FD2, dark: 0x58A7F7)
    static let operatorPurple = Color.dynamic(light: 0x7B5BC7, dark: 0xA890F4)
    static let personaOrange = Color.dynamic(light: 0xE78924, dark: 0xFFAC4D)
    static let qualityGreen = Color.dynamic(light: 0x3E9D52, dark: 0x6BCB7B)
    static let outputTeal = Color.dynamic(light: 0x168C9A, dark: 0x4FC4D0)

    static func moduleColor(for kind: LibraryItemKind) -> Color {
        switch kind {
        case .rootSkill:
            return sourceBlue
        case .consultingAgent, .jobSkill:
            return operatorPurple
        case .personaSkill:
            return personaOrange
        case .qualityGate:
            return qualityGreen
        }
    }

    static func statusColor(for status: RunStatus) -> Color {
        switch status {
        case .idle, .pending:
            return Color.nwebTextSecondary
        case .running:
            return sourceBlue
        case .needsReview:
            return personaOrange
        case .approved, .done:
            return qualityGreen
        case .failed:
            return Color.nwebError
        }
    }
}

struct PipePort: View {
    let color: Color
    var filled = true

    var body: some View {
        Circle()
            .fill(filled ? color : PipesStyle.moduleFill)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(PipesStyle.portFill, lineWidth: 1.5))
            .shadow(color: color.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}

struct PipeConnector: View {
    var active = false
    var color: Color = PipesStyle.pipeLine

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(active ? color : PipesStyle.pipeLine.opacity(0.55))
                .frame(width: active ? 5 : 3)
                .frame(height: 28)
            Circle()
                .fill(active ? color : PipesStyle.pipeLine.opacity(0.55))
                .frame(width: active ? 10 : 7, height: active ? 10 : 7)
            Rectangle()
                .fill(active ? color : PipesStyle.pipeLine.opacity(0.55))
                .frame(width: active ? 5 : 3)
                .frame(height: 28)
        }
        .animation(.easeInOut(duration: 0.18), value: active)
    }
}

struct PipePaneHeader: View {
    let number: Int
    let title: String
    let subtitle: String
    let color: Color
    var trailing: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.nwebTitle)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12), in: Capsule())
            }
        }
        .padding(18)
        .background(PipesStyle.paneBackground)
    }
}

private struct PipePanelModifier: ViewModifier {
    let color: Color
    var emphasized: Bool

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(PipesStyle.moduleFill, in: RoundedRectangle(cornerRadius: PipesStyle.panelRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PipesStyle.panelRadius)
                    .stroke(emphasized ? color : Color.nwebBorder, lineWidth: emphasized ? 2 : 1)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(color)
                    .frame(height: 5)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: PipesStyle.panelRadius, topTrailingRadius: PipesStyle.panelRadius))
            }
            .shadow(color: Color.nwebTextPrimary.opacity(emphasized ? 0.12 : 0.06), radius: emphasized ? 12 : 6, x: 0, y: emphasized ? 5 : 2)
    }
}

private struct PipeModuleModifier: ViewModifier {
    let color: Color
    var selected: Bool
    var active: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PipesStyle.moduleRadius)
                    .fill(PipesStyle.moduleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PipesStyle.moduleRadius)
                    .stroke(selected ? color : Color.nwebBorder, lineWidth: selected ? 2.5 : 1)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(color)
                    .frame(height: 8)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: PipesStyle.moduleRadius, topTrailingRadius: PipesStyle.moduleRadius))
            }
            .shadow(color: color.opacity(active ? 0.22 : 0.08), radius: active ? 14 : 6, x: 0, y: active ? 6 : 2)
    }
}

extension View {
    func pipePanel(color: Color = Color.nwebAccent, emphasized: Bool = false) -> some View {
        modifier(PipePanelModifier(color: color, emphasized: emphasized))
    }

    func pipeModule(color: Color, selected: Bool = false, active: Bool = false) -> some View {
        modifier(PipeModuleModifier(color: color, selected: selected, active: active))
    }
}
