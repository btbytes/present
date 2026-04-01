import Foundation
import SwiftUI

struct Slide: Identifiable, Codable {
    var id: UUID
    var url: String

    init(id: UUID = .init(), url: String = "https://example.com") {
        self.id = id
        self.url = url
    }
}

@Observable
@MainActor
final class PresentationState {
    var slides: [Slide] = []
    var currentIndex: Int = 0
    var isPresenting: Bool = false
    var zoomLevel: Double = 1.0
    var sidebarVisible: Bool = true

    private static let autosaveKey = "presentAutosavedURLs"

    init() {
        if let urls = UserDefaults.standard.stringArray(forKey: Self.autosaveKey), !urls.isEmpty {
            slides = urls.map { Slide(url: $0) }
        }
    }

    var currentSlide: Slide? {
        guard slides.indices.contains(currentIndex) else { return nil }
        return slides[currentIndex]
    }

    func zoomIn() { zoomLevel = min(zoomLevel + 0.1, 5.0) }
    func zoomOut() { zoomLevel = max(zoomLevel - 0.1, 0.3) }
    func zoomReset() { zoomLevel = 1.0 }
    func toggleSidebar() { sidebarVisible.toggle() }

    func goToNext() {
        guard !slides.isEmpty else { return }
        currentIndex = (currentIndex + 1) % slides.count
    }

    func goToPrevious() {
        guard !slides.isEmpty else { return }
        currentIndex = (currentIndex - 1 + slides.count) % slides.count
    }

    func addSlide() {
        let slide = Slide()
        slides.append(slide)
        currentIndex = slides.count - 1
        saveToDisk()
    }

    func deleteSlide(at index: Int) {
        guard slides.indices.contains(index) else { return }
        slides.remove(at: index)
        if slides.isEmpty {
            currentIndex = 0
        } else {
            currentIndex = min(currentIndex, slides.count - 1)
        }
        saveToDisk()
    }

    func selectSlide(_ slideID: UUID) {
        guard let index = slides.firstIndex(where: { $0.id == slideID }) else { return }
        currentIndex = index
    }

    func moveSlide(from source: IndexSet, to destination: Int) {
        slides.move(fromOffsets: source, toOffset: destination)
        saveToDisk()
    }

    func saveToDisk() {
        UserDefaults.standard.set(slides.map(\.url), forKey: Self.autosaveKey)
    }

    func load(from url: URL) throws {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let urls = contents.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !urls.isEmpty else { throw LoadError.emptyFile }
        slides = urls.map { Slide(url: $0) }
        currentIndex = 0
        saveToDisk()
    }

    func save(to url: URL) throws {
        let contents = slides.map(\.url).joined(separator: "\n") + "\n"
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    enum LoadError: LocalizedError {
        case emptyFile
        var errorDescription: String? {
            switch self {
            case .emptyFile: "File contains no URLs"
            }
        }
    }
}
