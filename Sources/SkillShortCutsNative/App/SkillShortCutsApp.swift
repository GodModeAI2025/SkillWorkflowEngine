import AppKit
import SwiftUI

@main
struct SkillShortCutsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("SkillShortCuts", id: "main") {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.theme.colorScheme)
                .frame(minWidth: 1180, minHeight: 760)
                .task {
                    await store.bootstrap()
                }
        }
        .commands {
            CommandMenu("Workflow") {
                Button("Workflow speichern") {
                    store.saveWorkflow()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button(store.primaryRunActionTitle) {
                    store.triggerPrimaryRunAction()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!store.canUsePrimaryRunAction)

                Button("Lauf abbrechen und resetten") {
                    store.abortAndResetRun()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.canAbortOrResetRun)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension AppThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
