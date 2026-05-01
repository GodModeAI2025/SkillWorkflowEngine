import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HSplitView {
            DataLibraryView()
                .frame(minWidth: 310, idealWidth: 350, maxWidth: 430)

            TeamComposerView()
                .frame(minWidth: 430, idealWidth: 560)

            InspectorRunView()
                .frame(minWidth: 360, idealWidth: 420, maxWidth: 520)
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
                    Task { await store.startRun() }
                } label: {
                    Label("Ausführen", systemImage: "play.fill")
                }
                .disabled(store.workflow.steps.isEmpty || store.isRunning)
            }
        }
        .font(.enbwBody)
        .tint(.enbwAccent)
        .foregroundStyle(Color.enbwTextPrimary)
        .background(Color.enbwBackgroundPrimary)
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
