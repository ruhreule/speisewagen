import SwiftUI

struct DayRowView: View {
    let date: Date
    let mealName: String?
    let isEditing: Bool
    @Binding var editingText: String
    let onStartEditing: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var isWeekend: Bool {
        let w = Calendar.current.component(.weekday, from: date)
        return w == 1 || w == 7
    }

    private var dayAbbrev: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "EEE"
        return fmt.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "dd.MM."
        return fmt.string(from: date)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent border for today
            Rectangle()
                .fill(isToday ? Color.swAccent : Color.swBg)
                .frame(width: 3)

            HStack(alignment: .center, spacing: 14) {
                // Day label column
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

                // Vertical separator
                Rectangle()
                    .fill(Color.swBorder)
                    .frame(width: 1, height: 36)

                // Edit or display
                if isEditing {
                    TextField("Gericht eintragen…", text: $editingText)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { onSave() }
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swText)

                    Button(action: onSave) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                editingText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.swMuted : Color.green
                            )
                    }
                    .disabled(editingText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.swMuted)
                    }
                } else {
                    Group {
                        if let name = mealName {
                            Text(name)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.swText)
                        } else {
                            Text(isWeekend ? "Freier Tag" : "Noch nichts geplant")
                                .font(Font.system(size: 15, weight: .light).italic())
                                .foregroundStyle(Color.swMuted.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.swBg)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
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
        .task(id: isEditing) {
            if isEditing {
                try? await Task.sleep(for: .milliseconds(50))
                focused = true
            } else {
                focused = false
            }
        }
    }
}
