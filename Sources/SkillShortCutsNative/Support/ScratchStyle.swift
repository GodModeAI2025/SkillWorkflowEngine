import SwiftUI

enum ScratchStyle {
    static let blockRadius: CGFloat = 14
    static let panelRadius: CGFloat = 18

    static let workspaceBackground = Color.dynamic(light: 0xEFF6FF, dark: 0x171B24)
    static let paletteBackground = Color.dynamic(light: 0xF7FBFF, dark: 0x181D26)
    static let stageBackground = Color.dynamic(light: 0xFFFFFF, dark: 0x232832)

    static let motionBlue = Color.dynamic(light: 0x4C97FF, dark: 0x5FA4FF)
    static let looksPurple = Color.dynamic(light: 0x9966FF, dark: 0xA881FF)
    static let soundPink = Color.dynamic(light: 0xCF63CF, dark: 0xD77AD7)
    static let eventYellow = Color.dynamic(light: 0xFFBF00, dark: 0xFFCA2E)
    static let controlOrange = Color.dynamic(light: 0xFFAB19, dark: 0xFFB83D)
    static let sensingBlue = Color.dynamic(light: 0x5CB1D6, dark: 0x71BFDF)
    static let operatorsGreen = Color.dynamic(light: 0x59C059, dark: 0x6CCC6C)
    static let variablesOrange = Color.dynamic(light: 0xFF8C1A, dark: 0xFF9D3D)
    static let myBlocksRed = Color.dynamic(light: 0xFF6680, dark: 0xFF7F94)

    static func blockColor(for kind: LibraryItemKind) -> Color {
        switch kind {
        case .rootSkill:
            return Color.nwebTextSecondary
        case .consultingAgent:
            return looksPurple
        case .jobSkill:
            return looksPurple
        case .personaSkill:
            return variablesOrange
        case .qualityGate:
            return operatorsGreen
        }
    }

    static func statusColor(for status: RunStatus) -> Color {
        switch status {
        case .idle, .pending:
            return Color.nwebTextSecondary
        case .running:
            return eventYellow
        case .needsReview:
            return controlOrange
        case .approved, .done:
            return operatorsGreen
        case .failed:
            return Color.nwebError
        }
    }

    static func headerNumber(_ number: Int, color: Color) -> some View {
        Text("\(number)")
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ScratchBlockModifier: ViewModifier {
    let color: Color
    var selected: Bool
    var active: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
                        .fill(Color.nwebBackgroundPrimary)
                    RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
                        .fill(color.opacity(active ? 0.16 : 0.09))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 8)
                        .padding(.vertical, 8)
                        .padding(.leading, 7)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: ScratchStyle.blockRadius)
                    .stroke(selected ? color : Color.nwebBorder, lineWidth: selected ? 2.5 : 1)
            )
            .shadow(color: color.opacity(active ? 0.22 : 0.08), radius: active ? 12 : 5, x: 0, y: active ? 5 : 2)
    }
}

extension View {
    func scratchBlock(color: Color, selected: Bool = false, active: Bool = false) -> some View {
        modifier(ScratchBlockModifier(color: color, selected: selected, active: active))
    }

    func scratchPanel() -> some View {
        padding(18)
            .background(Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: ScratchStyle.panelRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ScratchStyle.panelRadius)
                    .stroke(Color.nwebBorder)
            )
            .shadow(color: Color.nwebTextPrimary.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}
