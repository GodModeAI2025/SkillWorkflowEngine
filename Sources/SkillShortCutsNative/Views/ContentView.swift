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
                    Label("Neu", systemImage: "doc.badge.plus")
                }

                Button {
                    store.saveWorkflow()
                } label: {
                    Label("Speichern", systemImage: "square.and.arrow.down")
                }

                Button {
                    store.abortAndResetRun()
                } label: {
                    Label("Abbrechen", systemImage: "xmark.octagon")
                }
                .disabled(!store.canAbortOrResetRun)
                .help("Aktuellen Lauf abbrechen und Run-Zustand zurücksetzen. Die Workflow-Konfiguration bleibt erhalten.")

                Button {
                    store.triggerPrimaryRunAction()
                } label: {
                    Label(store.primaryRunActionTitle, systemImage: store.primaryRunActionIcon)
                }
                .disabled(!store.canUsePrimaryRunAction)
                .help(store.hasReviewWaiting ? "Aktuellen QS-Schritt freigeben und Workflow fortsetzen" : "Workflow ausführen")
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
