import SwiftUI
import VisionKit

/// Eine Zeile im Wochenplan, die einen einzelnen Tag darstellt.
///
/// Im Anzeigemodus zeigt sie Wochentag, Datum und den Gerichtnamen (oder einen
/// Platzhalter). Im Bearbeitungsmodus erscheint ein TextField mit Speichern/
/// Abbrechen-Buttons. Der Wechsel zwischen den Modi wird von `ContentView` gesteuert;
/// diese View ist zustandslos bis auf den Fokus des Textfelds.
struct DayRowView: View {
    let date: Date
    let mealName: String?
    /// Wird von ContentView übergeben; wenn true, schaltet die Zeile in den Editiermodus.
    let isEditing: Bool
    /// Geteilt mit ContentView, damit Auto-Save beim Zeilenwechsel funktioniert.
    @Binding var editingText: String
    /// UUID des verknüpften Rezepts, wenn der Eintrag per Scan oder Autocomplete verlinkt wurde.
    var recipeID: UUID? = nil
    let onStartEditing: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    var onScanRecipe: (() -> Void)? = nil
    var onOpenRecipe: (() -> Void)? = nil

    /// Steuert den Keyboard-Fokus des TextField. Wird in `onChange(of: isEditing)`
    /// synchronisiert, damit das Keyboard beim Aktivieren der Zeile automatisch erscheint.
    @FocusState private var focused: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    // Statische Formatter: einmalig erstellt, für alle Instanzen geteilt.
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE"
        return f
    }()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("Md")
        return f
    }()

    private var dayAbbrev: String {
        // Der Punkt am Ende (z. B. "Mo.") wird entfernt für ein saubereres Layout.
        Self.dayFmt.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private var dateString: String {
        Self.dateFmt.string(from: date)
    }

    /// Gibt an, ob der aktuelle Eingabetext nach dem Trimmen nicht leer ist.
    /// Wird für den Speichern-Button (Farbe + disabled-Status) verwendet und
    /// als berechnete Eigenschaft extrahiert, um doppeltes `.trimmingCharacters`
    /// im Body zu vermeiden.
    private var hasValidInput: Bool {
        !editingText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            // Linke Akzentlinie: 3 px breiter Streifen in der Akzentfarbe für heute,
            // ansonsten in der Hintergrundfarbe (unsichtbar, aber Platz haltend).
            Rectangle()
                .fill(isToday ? Color.swAccent : Color.swBg)
                .frame(width: 3)

            HStack(alignment: .center, spacing: 14) {
                // Datumsspalte: Kurzbezeichnung des Wochentags und numerisches Datum
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayAbbrev.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(isToday ? Color.swAccent : Color.swMuted)
                    Text(dateString)
                        .font(.system(size: 12))
                        .foregroundStyle(isToday ? Color.swAccent : Color.swMuted)
                }
                .frame(width: 34, alignment: .leading)

                // Vertikaler Trennstrich zwischen Datumsspalte und Inhaltsbereich
                Rectangle()
                    .fill(Color.swBorder)
                    .frame(width: 1, height: 36)

                if isEditing {
                    TextField("Gericht eintragen…", text: $editingText)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { onSave() }
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swText)

                    if let onScanRecipe {
                        Button(action: onScanRecipe) {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.swAccent)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Speichern-Button: grün wenn gültige Eingabe, gedämpft wenn leer
                    Button(action: onSave) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(hasValidInput ? Color.green : Color.swMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasValidInput)

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.swMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Group {
                        if let name = mealName {
                            Text(name)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.swText)
                        } else {
                            Text("Noch nichts geplant")
                                .font(Font.system(size: 15, weight: .light).italic())
                                .foregroundStyle(Color.swMuted.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Buch-Icon erscheint, wenn ein Rezept verknüpft ist.
                    // buttonStyle(.plain) + frame stellen sicher, dass der Button-Gesture
                    // gegenüber dem onTapGesture der Zeile Vorrang hat und die
                    // Trefferfläche groß genug ist (HIG: mind. 44×44 pt).
                    if recipeID != nil, let onOpenRecipe {
                        Button(action: onOpenRecipe) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.swAccent)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Löschen-Button erscheint nur, wenn ein Gericht eingetragen ist
                    if mealName != nil {
                        Button {
                            onDelete()
                        } label: {
                            Text("×")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.swMuted.opacity(0.6))
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isToday ? Color.swAccent.opacity(0.05) : Color.swBg)
        }
        .listRowInsets(EdgeInsets())        // Kein Standard-Inset, damit der Akzentstreifen bündig ist
        .listRowBackground(Color.swBg)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())          // Gesamte Fläche ist tappable, nicht nur Text
        .onTapGesture {
            if !isEditing { onStartEditing() }
        }
        .swipeActions(edge: .trailing) {
            if mealName != nil {
                Button(role: .destructive, action: onDelete) {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        // Fokus wird synchron mit `isEditing` gesetzt: Keyboard erscheint automatisch,
        // wenn ContentView diese Zeile in den Editiermodus schaltet.
        .onChange(of: isEditing) { _, newValue in
            focused = newValue
        }
    }
}
