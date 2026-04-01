import SwiftUI

struct ContentView: View {
    @Bindable var state: PresentationState
    @State private var selection: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(state.slides) { slide in
                        slideRow(slide)
                    }
                    .onMove(perform: moveSlides)
                    .onDelete(perform: deleteSlides)
                }
                .listStyle(.sidebar)
                .onChange(of: selection) {
                    if let selection { state.selectSlide(selection) }
                }

                HStack {
                    Button(action: state.addSlide) {
                        Image(systemName: "plus")
                    }
                    Button(action: deleteSelected) {
                        Image(systemName: "minus")
                    }
                    .disabled(selection == nil)
                    Spacer()
                }
                .padding(8)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 500)
        } detail: {
            if let slide = state.currentSlide {
                WebView(url: slide.url, pageZoom: state.zoomLevel)
            } else {
                ContentUnavailableView(
                    "No slide selected",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Add a URL to get started")
                )
            }
        }
        .onAppear {
            if state.slides.isEmpty { state.addSlide() }
            if let first = state.slides.first { selection = first.id }
            columnVisibility = state.sidebarVisible ? .all : .detailOnly
        }
        .onChange(of: state.sidebarVisible) {
            withAnimation {
                columnVisibility = state.sidebarVisible ? .all : .detailOnly
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func slideRow(_ slide: Slide) -> some View {
        if let index = state.slides.firstIndex(where: { $0.id == slide.id }) {
            HStack {
                Text("\(index + 1).")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                    .draggable(slide.id.uuidString)
                TextField("URL", text: Binding(
                    get: { state.slides[index].url },
                    set: { state.slides[index].url = $0; state.saveToDisk() }
                ))
                .textFieldStyle(.roundedBorder)
            }
            .tag(slide.id)
            .dropDestination(for: String.self) { items, _ in
                guard let draggedIDString = items.first,
                      let draggedID = UUID(uuidString: draggedIDString),
                      let fromIndex = state.slides.firstIndex(where: { $0.id == draggedID }),
                      let toIndex = state.slides.firstIndex(where: { $0.id == slide.id })
                else { return false }
                withAnimation {
                    state.moveSlide(
                        from: IndexSet(integer: fromIndex),
                        to: toIndex > fromIndex ? toIndex + 1 : toIndex
                    )
                }
                return true
            }
        }
    }

    @MainActor
    private func moveSlides(from source: IndexSet, to destination: Int) {
        state.moveSlide(from: source, to: destination)
    }

    @MainActor
    private func deleteSlides(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            state.deleteSlide(at: index)
        }
        selection = nil
    }

    @MainActor
    private func deleteSelected() {
        guard let selection,
              let index = state.slides.firstIndex(where: { $0.id == selection })
        else { return }
        state.deleteSlide(at: index)
        self.selection = nil
    }
}
