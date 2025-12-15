import SwiftUI

// ------------------------------------------------------------
// MARK: - MODEL: Individual Highlight Entry
// ------------------------------------------------------------

public struct TextHighlight: Identifiable, Codable, Hashable {
    public let id: UUID
    public var word: String
    public var colorHex: String
    public var note: String?

    public init(word: String, color: Color, note: String? = nil) {
        self.id = UUID()
        self.word = word
        self.colorHex = color.toHex()
        self.note = note
    }

    public var color: Color {
        Color(hex: colorHex)
    }
}

// ------------------------------------------------------------
// MARK: - VIEW MODEL: Highlight Manager (Persistent)
// ------------------------------------------------------------

public class HighlightManager: ObservableObject {

    @Published public var highlights: [TextHighlight] = [] {
        didSet { saveHighlights() }
    }

    @Published public var selectedWord: String?
    @Published public var showColorPicker: Bool = false
    @Published public var showNoteEditor: Bool = false
    @Published public var noteText: String = ""

    private let storageKey = "HighlightStorage"

    public init() {
        loadHighlights()
    }

    // Highlight a word
    public func highlightWord(_ word: String, color: Color) {
        if let idx = highlights.firstIndex(where: { $0.word == word }) {
            highlights[idx].colorHex = color.toHex()
        } else {
            highlights.append(TextHighlight(word: word, color: color))
        }
    }

    // Save note
    public func saveNote(for word: String) {
        if let idx = highlights.firstIndex(where: { $0.word == word }) {
            highlights[idx].note = noteText
        }
    }

    // Lookup for color
    public func colorFor(_ word: String) -> Color? {
        highlights.first(where: { $0.word == word })?.color
    }

    // Lookup for note
    public func noteFor(_ word: String) -> String? {
        highlights.first(where: { $0.word == word })?.note
    }

    // ------------------------------------------------------------
    // MARK: - Persistence
    // ------------------------------------------------------------

    private func saveHighlights() {
        if let data = try? JSONEncoder().encode(highlights) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHighlights() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([TextHighlight].self, from: data)
        else { return }
        highlights = saved
    }
}

// ------------------------------------------------------------
// MARK: - PUBLIC MODIFIER API
// ------------------------------------------------------------

public extension View {
    func highlightable(text: String) -> some View {
        modifier(HighlightableModifier(originalText: text))
    }
}

public struct HighlightableModifier: ViewModifier {
    @StateObject private var manager = HighlightManager()
    let originalText: String

    public func body(content: Content) -> some View {
        HighlightContainer(text: originalText)
            .environmentObject(manager)
    }
}

// ------------------------------------------------------------
// MARK: - MAIN HIGHLIGHT CONTAINER
// ------------------------------------------------------------

public struct HighlightContainer: View {

    @EnvironmentObject var manager: HighlightManager
    let text: String
    private var words: [String] { text.split(separator: " ").map(String.init) }

    public var body: some View {
        VStack(alignment: .leading) {
            LineWrappedText(words: words, spacing: 6) { word in
                wordView(for: word)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .overlay(colorPickerOverlay)
        .overlay(notePopupOverlay)
    }

    // ------------------------------------------------------------
    // MARK: Word View Component
    // ------------------------------------------------------------
    private func wordView(for word: String) -> some View {
        Text(word)
            .padding(4)
            .background((manager.colorFor(word) ?? .clear).opacity(0.35))
            .cornerRadius(4)
            .overlay(
                Group {
                    if manager.noteFor(word) != nil {
                        Image(systemName: "pencil.tip")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .offset(x: 10, y: -10)
                    }
                },
                alignment: .topTrailing
            )
            .onTapGesture {
                manager.selectedWord = word
                manager.showColorPicker = true
            }
            .onLongPressGesture {
                manager.selectedWord = word
                manager.noteText = manager.noteFor(word) ?? ""
                manager.showNoteEditor = true
            }
    }

    // ------------------------------------------------------------
    // MARK: Color Picker Overlay
    // ------------------------------------------------------------
    private var colorPickerOverlay: some View {
        Group {
            if manager.showColorPicker {
                HStack {
                    ForEach([Color.yellow, .green, .pink, .blue], id: \.self) { c in
                        Circle()
                            .fill(c)
                            .frame(width: 28, height: 28)
                            .onTapGesture {
                                if let w = manager.selectedWord {
                                    manager.highlightWord(w, color: c)
                                }
                                manager.showColorPicker = false
                            }
                    }
                    Button("Cancel") {
                        manager.showColorPicker = false
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.85))

                .cornerRadius(12)
                .padding()
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: Note Editor Popup
    // ------------------------------------------------------------
    private var notePopupOverlay: some View {
        Group {
            if manager.showNoteEditor {
                VStack(spacing: 12) {
                    Text("Add Note")
                        .font(.headline)

                    TextField("Note…", text: $manager.noteText)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        if let w = manager.selectedWord {
                            manager.saveNote(for: w)
                        }
                        manager.showNoteEditor = false
                    }

                    Button("Cancel") {
                        manager.showNoteEditor = false
                    }
                }
                .padding()
                .frame(width: 260)
                .background(Color(.systemBackground).opacity(0.95))

                .cornerRadius(12)
            }
        }
    }
}

// ------------------------------------------------------------
// MARK: - TEXT WRAPPING ENGINE (Correct Words Layout)
// ------------------------------------------------------------

public struct LineWrappedText<WordView: View>: View {

    let words: [String]
    let spacing: CGFloat
    let wordView: (String) -> WordView

    public init(words: [String],
                spacing: CGFloat = 6,
                @ViewBuilder wordView: @escaping (String) -> WordView) {
        self.words = words
        self.spacing = spacing

        self.wordView = wordView
    }

    public var body: some View {
        GeometryReader { geo in
            buildLines(maxWidth: geo.size.width)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildLines(maxWidth: CGFloat) -> some View {

        var currentWidth: CGFloat = 0
        var lines: [[String]] = [[]]

        let widths: [String: CGFloat] = words.reduce(into: [:]) { r, w in
            let wWidth = w.width(usingFont: .systemFont(ofSize: 17)) + 16
            r[w] = wWidth
        }

        for word in words {
            let w = widths[word] ?? 0

            if currentWidth + w > maxWidth {
                lines.append([word])
                currentWidth = w
            } else {
                lines[lines.count - 1].append(word)
                currentWidth += w
            }
        }

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(lines, id: \.self) { line in
                HStack(spacing: spacing) {
                    ForEach(line, id: \.self) { w in
                        wordView(w)
                    }
                }
            }
        }
    }
}

// ------------------------------------------------------------
// MARK: - UTILITY EXTENSIONS
// ------------------------------------------------------------

extension String {
    func width(usingFont font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return (self as NSString).size(withAttributes: attributes).width
    }
}

extension Color {

    func toHex() -> String {
        let ui = UIColor(self)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(format: "%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }

    init(hex: String) {
        var clean = hex
        if clean.hasPrefix("#") { clean.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
