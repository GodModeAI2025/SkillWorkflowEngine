import AppKit
import SwiftUI

enum EnBWTheme {
    static let smallRadius: CGFloat = 6
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 16

    static var fontName: String {
        let families = NSFontManager.shared.availableFontFamilies
        return families.contains("EnBW Sans") ? "EnBW Sans" : "Arial"
    }
}

extension Font {
    static let enbwBody = Font.custom(EnBWTheme.fontName, size: 13)
    static let enbwCaption = Font.custom(EnBWTheme.fontName, size: 11)
    static let enbwHeadline = Font.custom(EnBWTheme.fontName, size: 15).weight(.semibold)
    static let enbwTitle = Font.custom(EnBWTheme.fontName, size: 18).weight(.semibold)
}

extension Color {
    static let enbwAccent = dynamic(light: 0x000099, dark: 0x4D4DFF)
    static let enbwOrange = dynamic(light: 0xFE8F11, dark: 0xFE8F11)
    static let enbwBackgroundPrimary = dynamic(light: 0xFFFFFF, dark: 0x1A1614)
    static let enbwBackgroundSecondary = dynamic(light: 0xF9F7F5, dark: 0x252120)
    static let enbwSidebar = dynamic(light: 0xF4F1EE, dark: 0x201C1A)
    static let enbwTextPrimary = dynamic(light: 0x322A26, dark: 0xF9F7F5)
    static let enbwTextSecondary = dynamic(light: 0x625A55, dark: 0xB0A9A3)
    static let enbwTextTertiary = dynamic(light: 0xB0A9A3, dark: 0x625A55)
    static let enbwSuccess = dynamic(light: 0x84C041, dark: 0x84C041)
    static let enbwWarning = dynamic(light: 0xFFBB00, dark: 0xFFBB00)
    static let enbwError = dynamic(light: 0xE20E00, dark: 0xE20E00)
    static let enbwBorder = dynamic(light: 0xE2C39A, dark: 0x3D3530, lightAlpha: 0.4, darkAlpha: 1)
    static let enbwAzure = dynamic(light: 0x1195EB, dark: 0x1195EB)

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
    func enbwCard(radius: CGFloat = EnBWTheme.mediumRadius) -> some View {
        padding(12)
            .background(Color.enbwBackgroundPrimary, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.enbwBorder)
            )
            .shadow(color: Color.enbwTextPrimary.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    func enbwInputBackground(radius: CGFloat = EnBWTheme.smallRadius) -> some View {
        scrollContentBackground(.hidden)
            .padding(6)
            .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.enbwBorder)
            )
    }
}
