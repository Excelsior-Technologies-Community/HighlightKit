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
    private var words: [String] { tokenize(text) }


    public var body: some View {
        VStack(alignment: .leading) {
            // MARK: - CHANGE: Removed 'spacing: 3' from LineWrappedText init
            LineWrappedText(words: words) { word in
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
            .padding(2)
//            .frame(maxWidth: .infinity)
            .background((manager.colorFor(word) ?? .clear).opacity(0.35))
            .cornerRadius(4)
            .padding(.leading,2)
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
private func tokenize(_ text: String) -> [String] {
    var words: [String] = []
    var current = ""

    for scalar in text.unicodeScalars {
        if CharacterSet.whitespacesAndNewlines.contains(scalar) {
            // end word
            if !current.isEmpty { words.append(current) }
            current = ""
        }
        else if CharacterSet.punctuationCharacters.contains(scalar) == false {
            // normal visible character
            current.unicodeScalars.append(scalar)
        }
        else {
            // punctuation should become part of the same chunk
            current.unicodeScalars.append(scalar)
        }
    }

    if !current.isEmpty {
        words.append(current)
    }

    return words
}

public struct LineWrappedText<WordView: View>: View {

    let words: [String]
    // MARK: - CHANGE: Removed spacing property
    let wordView: (String) -> WordView

    public init(words: [String],
                // MARK: - CHANGE: Removed spacing parameter from init
                @ViewBuilder wordView: @escaping (String) -> WordView) {
        self.words = words
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
        
        // MARK: - CHANGE: Defined fixed spacing values
        let interWordSpacing: CGFloat = 4.0 // Minimal space to separate words
        let interLineSpacing: CGFloat = 0.0 // No extra space between lines

        // In wordView, there is a padding of 4 points on all sides, contributing 8 to the width.
        // The calculated width must also include the space that follows the word (interWordSpacing),
        // which was missing in the original logic.
        let widths: [String: CGFloat] = words.reduce(into: [:]) { r, w in
            let wWidthWithPadding = w.width(usingFont: .systemFont(ofSize: 17)) + 8
            r[w] = wWidthWithPadding + interWordSpacing
        }

        for word in words {
            let wWithGap = widths[word] ?? 0 // width of word + padding + interWordSpacing

            // Correction to wrapping logic: check if word+gap fits
            if currentWidth + wWithGap > maxWidth {
                // Start a new line
                lines.append([word])
                currentWidth = wWithGap
            } else {
                // Append to current line and update width
                lines[lines.count - 1].append(word)
                currentWidth += wWithGap
            }
        }

        // MARK: - CHANGE: Set VStack and HStack spacing to fixed values (0 and 4.0)
        return VStack(alignment: .leading, spacing: interLineSpacing) {
            ForEach(lines, id: \.self) { line in
                HStack(spacing: interWordSpacing) {
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
