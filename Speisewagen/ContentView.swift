import SwiftUI
import CloudKit

struct ContentView: View {
    @EnvironmentObject private var store: MealStore

    @State private var weekOffset = 0
    @State private var editingDate: Date? = nil
    @State private var editingText: String = ""
    @State private var isPreparingShare = false
    @State private var activeShare: CKShare? = nil
    @State private var activeContainer: CKContainer? = nil
    @State private var showShareSheet = false
    @State private var sharingError: String? = nil
    @State private var showSideMenu = false

    private var allMeals: [MealEntry] { store.meals }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                headerView
                mealList
                footerView
            }
            .background(Color.swBg)
            .sheet(isPresented: $showShareSheet) {
                if let share = activeShare, let ckContainer = activeContainer {
                    CloudSharingView(share: share, container: ckContainer) {
                        showShareSheet = false
                    }
                }
            }
            .alert("Hinweis", isPresented: Binding(
                get: { sharingError != nil },
                set: { if !$0 { sharingError = nil } }
            )) {
                Button("OK") { sharingError = nil }
            } message: {
                Text(sharingError ?? "")
            }

            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showSideMenu = false }

                SideMenuView(onClose: { showSideMenu = false })
                    .frame(width: UIScreen.main.bounds.width * 0.78)
                    .ignoresSafeArea()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSideMenu)
    }

    // MARK: – Header

    private var headerView: some View {
        VStack(spacing: 14) {
            brandRow
            progressBarView
            weekNavRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background { Color.white.ignoresSafeArea(edges: .top) }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.swBorder).frame(height: 0.5)
        }
    }

    private var brandRow: some View {
        HStack(alignment: .center, spacing: 12) {
            SpeisewagenLogo(size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text("Speisewagen")
                    .font(.custom("Georgia", size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
                Text("Wochenmenü")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.swMuted)
            }

            Spacer()

            shareButton

            menuButton
        }
    }

    private var shareButton: some View {
        Button {
            initiateSharing()
        } label: {
            Group {
                if isPreparingShare {
                    ProgressView()
                        .tint(Color.swMuted)
                } else {
                    Image(systemName: store.isShared ? "person.2.fill" : "person.badge.plus")
                        .font(.system(size: 17))
                        .foregroundStyle(store.isShared ? Color.swAccent : Color.swMuted)
                }
            }
            .frame(width: 34, height: 34)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(store.isShared ? Color.swAccent.opacity(0.3) : Color.swBorder, lineWidth: 1)
            )
        }
        .disabled(isPreparingShare)
    }

    private var menuButton: some View {
        Button {
            showSideMenu = true
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17))
                .foregroundStyle(Color.swMuted)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.swBorder, lineWidth: 1)
                )
        }
    }

    private func initiateSharing() {
        guard !allMeals.isEmpty else {
            sharingError = "Füge zuerst mindestens ein Gericht hinzu."
            return
        }
        isPreparingShare = true
        store.prepareShare { share, container, error in
            isPreparingShare = false
            if let error {
                sharingError = error.localizedDescription
            } else if let share, let container {
                activeShare = share
                activeContainer = container
                showShareSheet = true
            }
        }
    }

    private var progressBarView: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(i < filledCount ? Color.swAccent : Color.swBorder)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: filledCount)
            }
        }
    }

    private var weekNavRow: some View {
        HStack(spacing: 8) {
            navButton(direction: -1)
            Spacer()
            HStack(spacing: 6) {
                if weekOffset == 0 {
                    Circle()
                        .fill(Color.swAccent)
                        .frame(width: 6, height: 6)
                }
                Text(weekRangeTitle)
                    .font(Font.custom("Georgia", size: 13).italic())
                    .foregroundStyle(Color.swMuted)
            }
            Spacer()
            navButton(direction: 1)
        }
    }

    private func navButton(direction: Int) -> some View {
        Button {
            weekOffset += direction
        } label: {
            Text(direction < 0 ? "‹" : "›")
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(Color.swMuted)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.swBorder, lineWidth: 1)
                )
        }
    }

    // MARK: – List

    private var mealList: some View {
        List {
            Text("Diese Woche")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.swMuted)
                .listRowBackground(Color.swBg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            ForEach(weekDates, id: \.timeIntervalSince1970) { date in
                DayRowView(
                    date: date,
                    mealName: meal(for: date)?.name,
                    isEditing: editingDate == date,
                    editingText: $editingText,
                    onStartEditing: { startEditing(date: date) },
                    onSave: { save(for: date) },
                    onCancel: { editingDate = nil },
                    onDelete: { delete(for: date) }
                )

                if editingDate == date && !suggestions.isEmpty {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            editingText = suggestion
                        } label: {
                            HStack {
                                Spacer().frame(width: 54)
                                Text(suggestion)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.swText)
                                Spacer()
                                Text("↩")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.swAccent.opacity(0.7))
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                    }
                }
            }

            if !store.allNames.isEmpty {
                HStack(spacing: 8) {
                    Text("💡")
                        .font(.system(size: 16))
                    Text("Tippe auf einen Tag und gib die ersten Buchstaben ein – deine früheren Gerichte werden vorgeschlagen.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.swMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.swBorder)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowBackground(Color.swBg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.swBg)
    }

    // MARK: – Footer

    private var footerView: some View {
        Text("Guten Appetit")
            .font(Font.custom("Georgia", size: 11).italic())
            .kerning(1)
            .foregroundStyle(Color.swMuted.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                Color.white.ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Color.swBorder).frame(height: 0.5)
            }
    }

    // MARK: – Helpers

    private var filledCount: Int {
        weekDates.filter { meal(for: $0) != nil }.count
    }

    private var suggestions: [String] {
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return store.allNames.filter {
            $0.localizedCaseInsensitiveContains(trimmed) &&
            $0.caseInsensitiveCompare(trimmed) != .orderedSame
        }
    }

    private var weekDates: [Date] {
        let monday = mondayOfWeek(offset: weekOffset)
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: monday)
        }
    }

    private var weekRangeTitle: String {
        guard let monday = weekDates.first, let lastDay = weekDates.last else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "dd. MMM"
        let fmtYear = DateFormatter()
        fmtYear.locale = Locale(identifier: "de_DE")
        fmtYear.dateFormat = "dd. MMM yyyy"
        return "\(fmt.string(from: monday)) – \(fmtYear.string(from: lastDay))"
    }

    private func meal(for date: Date) -> MealEntry? {
        store.meal(for: date)
    }

    private func startEditing(date: Date) {
        if let prev = editingDate, prev != date {
            let trimmed = editingText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { store.save(name: trimmed, for: prev) }
        }
        editingText = meal(for: date)?.name ?? ""
        editingDate = date
    }

    private func save(for date: Date) {
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            editingDate = nil
            return
        }
        store.save(name: trimmed, for: date)
        editingDate = nil
    }

    private func delete(for date: Date) {
        store.delete(for: date)
        if editingDate == date { editingDate = nil }
    }

    private func mondayOfWeek(offset: Int) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let monday = cal.date(from: comps)!
        return cal.date(byAdding: .weekOfYear, value: offset, to: monday)!
    }
}
