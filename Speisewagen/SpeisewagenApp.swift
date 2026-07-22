import SwiftUI
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        MealStore.shared.acceptShare(metadata: cloudKitShareMetadata)
    }
}

@main
struct SpeisewagenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = MealStore.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            TabView {
                // Tab 1: Wochenplan
                ContentView()
                    .tabItem {
                        Label("Wochenplan", systemImage: "calendar")
                    }

                // Tab 2: Rezepte – eigener NavigationStack, damit RecipeDetailView
                // innerhalb des Tabs navigiert und nicht über den Tab-Bar hinausgeht.
                NavigationStack {
                    RecipeListView()
                }
                .tabItem {
                    Label("Rezepte", systemImage: "book.closed")
                }

                // Tab 3: Sekundäre Inhalte (Impressum)
                NavigationStack {
                    MehrView()
                }
                .tabItem {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
            // Akzentfarbe gilt für alle Tab-Icons und Navigationslinks
            .tint(Color.swAccent)
            .environmentObject(store)
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in }
            )) {
                OnboardingView()
            }
        }
    }
}

/// Dritter Tab: listet sekundäre App-Inhalte auf.
private struct MehrView: View {
    @State private var showOnboarding = false

    var body: some View {
        List {
            NavigationLink {
                RecipePrintView()
            } label: {
                Label("Rezeptkarten drucken", systemImage: "printer")
                    .foregroundStyle(Color.swText)
            }
            NavigationLink {
                TipJarView()
            } label: {
                Label("Trinkgeld", systemImage: "heart")
                    .foregroundStyle(Color.swText)
            }
            Button {
                showOnboarding = true
            } label: {
                Label("App-Einführung", systemImage: "questionmark.circle")
                    .foregroundStyle(Color.swText)
            }
            NavigationLink {
                ImpressumView()
            } label: {
                Label("Impressum", systemImage: "info.circle")
                    .foregroundStyle(Color.swText)
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.swBg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Mehr")
                    .font(.custom("Georgia", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.swText)
            }
        }
    }
}
