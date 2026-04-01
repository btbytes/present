import SwiftUI
import UniformTypeIdentifiers

@main
struct PresentApp: App {
    @State private var state = PresentationState()
    @State private var presentationController = PresentationWindowController()
    @State private var server = RemoteServer()

    init() {
        server.start(state: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .onReceive(NotificationCenter.default.publisher(for: .remotePlay)) { _ in
                    guard !state.isPresenting else { return }
                    presentationController.open(state: state)
                }
                .onReceive(NotificationCenter.default.publisher(for: .remoteStop)) { _ in
                    guard state.isPresenting else { return }
                    presentationController.close(state: state)
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Divider()
                Button("Open...") { openFile() }
                    .keyboardShortcut("o")

                Button("Save As...") { saveFile() }
                    .keyboardShortcut("s")
            }

            CommandMenu("View") {
                Toggle("Sidebar", isOn: Binding(
                    get: { state.sidebarVisible },
                    set: { _ in state.toggleSidebar() }
                ))
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Button("Zoom In") { state.zoomIn() }
                    .keyboardShortcut("=")

                Button("Zoom Out") { state.zoomOut() }
                    .keyboardShortcut("-")

                Button("Actual Size") { state.zoomReset() }
                    .keyboardShortcut("0")
            }

            CommandMenu("Presentation") {
                Button("Play") { presentationController.open(state: state) }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(state.slides.isEmpty)
            }
        }
    }

    @MainActor
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.load(from: url)
        } catch {
            presentError(error)
        }
    }

    @MainActor
    private func saveFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "presentation.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.save(to: url)
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
