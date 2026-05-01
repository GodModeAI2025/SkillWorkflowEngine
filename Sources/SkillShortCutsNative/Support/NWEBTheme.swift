import AppKit
import SwiftUI

enum NWEBTheme {
    static let smallRadius: CGFloat = 6
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 16

    static var fontName: String {
        let families = NSFontManager.shared.availableFontFamilies
        return families.contains("NWEB Sans") ? "NWEB Sans" : "Arial"
    }
}

extension Font {
    static let nwebBody = Font.custom(NWEBTheme.fontName, size: 13)
    static let nwebCaption = Font.custom(NWEBTheme.fontName, size: 11)
    static let nwebHeadline = Font.custom(NWEBTheme.fontName, size: 15).weight(.semibold)
    static let nwebTitle = Font.custom(NWEBTheme.fontName, size: 18).weight(.semibold)
}

extension Color {
    static let nwebAccent = dynamic(light: 0x000099, dark: 0x4D4DFF)
    static let nwebOrange = dynamic(light: 0xFE8F11, dark: 0xFE8F11)
    static let nwebBackgroundPrimary = dynamic(light: 0xFFFFFF, dark: 0x1A1614)
    static let nwebBackgroundSecondary = dynamic(light: 0xF9F7F5, dark: 0x252120)
    static let nwebSidebar = dynamic(light: 0xF4F1EE, dark: 0x201C1A)
    static let nwebTextPrimary = dynamic(light: 0x322A26, dark: 0xF9F7F5)
    static let nwebTextSecondary = dynamic(light: 0x625A55, dark: 0xB0A9A3)
    static let nwebTextTertiary = dynamic(light: 0xB0A9A3, dark: 0x625A55)
    static let nwebSuccess = dynamic(light: 0x84C041, dark: 0x84C041)
    static let nwebWarning = dynamic(light: 0xFFBB00, dark: 0xFFBB00)
    static let nwebError = dynamic(light: 0xE20E00, dark: 0xE20E00)
    static let nwebBorder = dynamic(light: 0xE2C39A, dark: 0x3D3530, lightAlpha: 0.4, darkAlpha: 1)
    static let nwebAzure = dynamic(light: 0x1195EB, dark: 0x1195EB)

    static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension View {
    func nwebCard(radius: CGFloat = NWEBTheme.mediumRadius) -> some View {
        padding(12)
            .background(Color.nwebBackgroundPrimary, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.nwebBorder)
            )
            .shadow(color: Color.nwebTextPrimary.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    func nwebInputBackground(radius: CGFloat = NWEBTheme.smallRadius) -> some View {
        scrollContentBackground(.hidden)
            .padding(6)
            .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.nwebBorder)
            )
    }
}
