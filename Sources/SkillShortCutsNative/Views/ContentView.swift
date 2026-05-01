import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HSplitView {
            DataLibraryView()
                .frame(minWidth: 390, idealWidth: 430, maxWidth: 520)

            TeamComposerView()
                .frame(minWidth: 560, idealWidth: 680)

            InspectorRunView()
                .frame(minWidth: 440, idealWidth: 520, maxWidth: 620)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.newWorkflow()
                } label: {
                    Label("Neue Pipe", systemImage: "doc.badge.plus")
                }

                Button {
                    store.saveWorkflow()
                } label: {
                    Label("Pipe speichern", systemImage: "square.and.arrow.down")
                }

                Button {
                    store.abortAndResetRun()
                } label: {
                    Label("Stop / Reset", systemImage: "xmark.octagon")
                }
                .disabled(!store.canAbortOrResetRun)
                .help("Aktuellen Pipe-Lauf abbrechen und Run-Zustand zurücksetzen. Die Pipe-Konfiguration bleibt erhalten.")

                Button {
                    store.triggerPrimaryRunAction()
                } label: {
                    Label(store.primaryRunActionTitle == "Ausführen" ? "Run Pipe" : store.primaryRunActionTitle, systemImage: store.primaryRunActionIcon)
                }
                .disabled(!store.canUsePrimaryRunAction)
                .help(store.hasReviewWaiting ? "Aktuellen QS-Knoten freigeben und Pipe fortsetzen" : "Pipe ausführen")
            }
        }
        .font(.nwebBody)
        .tint(.nwebAccent)
        .foregroundStyle(Color.nwebTextPrimary)
        .background(Color.nwebBackgroundPrimary)
        .alert("SkillShortCuts", isPresented: Binding(
            get: { !store.errorMessage.isEmpty },
            set: { if !$0 { store.errorMessage = "" } }
        )) {
            Button("OK") { store.errorMessage = "" }
        } message: {
            Text(store.errorMessage)
        }
    }
}
