import CoreData
import CloudKit
import SwiftUI

/// Zentraler Datenspeicher der App. Hält alle Mahlzeiten im Arbeitsspeicher,
/// vermittelt zwischen SwiftUI-Views und CoreData und steuert die iCloud-Synchronisation.
///
/// Als Singleton (`MealStore.shared`) wird die Instanz einmalig erzeugt und über
/// `@EnvironmentObject` in den View-Baum injiziert.
final class MealStore: ObservableObject {
    static let shared = MealStore()

    /// Alle gespeicherten Mahlzeiten, aufsteigend nach Datum sortiert.
    /// Wird nach jedem Speichern/Löschen und bei Remote-Änderungen aus iCloud neu befüllt.
    @Published var meals: [MealEntry] = []

    /// Deduplizierte, alphabetisch sortierte Liste aller jemals eingegebenen Gerichtnamen.
    /// Wird für die Autocomplete-Vorschläge in der Editierzeile verwendet.
    /// `private(set)`, damit Views lesen, aber nicht schreiben können.
    @Published private(set) var allNames: [String] = []

    /// Zeigt an, ob mindestens ein aktiver CKShare existiert (private oder shared Store).
    /// Steuert das Icon und den Rahmen des Share-Buttons im Header.
    @Published var isShared = false

    /// Der NSPersistentCloudKitContainer, der sowohl CoreData als auch CloudKit-Synchronisation
    /// kapselt. Zwei Stores: privater iCloud-Store und geteilter (shared) Store.
    let container: NSPersistentCloudKitContainer

    private var privateStore: NSPersistentStore?
    private var sharedStore: NSPersistentStore?

    private init() {
        // Das CoreData-Modell wird vollständig im Code aufgebaut (siehe makeModel()),
        // sodass keine .xcdatamodeld-Datei im Bundle nötig ist.
        container = NSPersistentCloudKitContainer(name: "Speisewagen",
                                                  managedObjectModel: Self.makeModel())
        setup()
    }

    // MARK: - Modell (kein .xcdatamodeld-File)

    /// Erstellt das CoreData-Modell programmgesteuert.
    /// Vorteil: Keine separate .xcdatamodeld-Ressource, die gepflegt und versioniert
    /// werden müsste – alle Modellinformationen sind im Code sichtbar und versionierbar.
    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "MealEntry"
        // Muss mit dem @objc(MealEntry)-Attribut in MealEntry.swift übereinstimmen,
        // damit CoreData die richtige Klasse instanziiert.
        entity.managedObjectClassName = "MealEntry"

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = true

        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = true

        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true

        entity.properties = [idAttr, dateAttr, nameAttr]
        model.entities = [entity]
        return model
    }

    // MARK: - Setup

    /// Konfiguriert und lädt die beiden Persistent Stores (privat + geteilt).
    /// Registriert außerdem den Observer für Remote-Änderungen aus iCloud.
    private func setup() {
        let baseURL = NSPersistentContainer.defaultDirectoryURL()

        // --- Privater Store: Nur der aktuelle Benutzer kann lesen/schreiben ---
        let privateDesc = NSPersistentStoreDescription(
            url: baseURL.appendingPathComponent("speisewagen.sqlite"))
        // History Tracking ist Voraussetzung für NSPersistentCloudKitContainer,
        // damit Änderungen korrekt mit iCloud synchronisiert werden können.
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        // Aktiviert lokale Benachrichtigungen, sobald Remote-Daten eintreffen.
        privateDesc.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let privateOpts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.eu.barann.speisewagen")
        privateOpts.databaseScope = .private
        privateDesc.cloudKitContainerOptions = privateOpts

        // --- Geteilter Store: Enthält Einträge, die andere Benutzer geteilt haben ---
        let sharedDesc = NSPersistentStoreDescription(
            url: baseURL.appendingPathComponent("speisewagen-shared.sqlite"))
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDesc.setOption(true as NSNumber,
                             forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let sharedOpts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.eu.barann.speisewagen")
        sharedOpts.databaseScope = .shared
        sharedDesc.cloudKitContainerOptions = sharedOpts

        container.persistentStoreDescriptions = [privateDesc, sharedDesc]

        // Änderungen aus anderen Kontexten (z.B. Background-Sync) werden automatisch
        // in den viewContext übernommen.
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Bei Konflikten gewinnt die Eigenschaft des Objekts im Speicher
        // (kein vollständiges Objekt-Überschreiben).
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Beide Stores werden asynchron geladen; der Completion-Handler wird
        // für jeden Store einzeln aufgerufen.
        container.loadPersistentStores { [weak self] storeDesc, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("⚠️ Store-Ladefehler: \(error)")
                } else if let url = storeDesc.url {
                    // Store-Referenzen merken, damit später fetch/share auf dem
                    // richtigen Store operieren können.
                    let store = self.container.persistentStoreCoordinator
                        .persistentStore(for: url)
                    if storeDesc.cloudKitContainerOptions?.databaseScope == .shared {
                        self.sharedStore = store
                    } else {
                        self.privateStore = store
                    }
                }
                self.fetch()
            }
        }

        // Wird ausgelöst, sobald iCloud neue Daten in einen der Stores geschrieben hat.
        // Ermöglicht Echtzeit-Updates ohne Polling.
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in self?.fetch() }
    }

    // MARK: - Fetch

    /// Liest alle Mahlzeiten aus dem viewContext und aktualisiert die @Published-Properties.
    /// Wird nach jeder lokalen Mutation sowie bei Remote-Änderungen aufgerufen.
    func fetch() {
        let req = NSFetchRequest<MealEntry>(entityName: "MealEntry")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        meals = (try? container.viewContext.fetch(req)) ?? []

        // Gerichtnamen deduplizieren und sortieren – in einem einzigen Durchlauf
        // durch meals, kombiniert aus compactMap (nil-Filter + guard für leere Strings)
        // und anschließendem Set für Einzigartigkeit.
        let uniqueNames = Set(meals.compactMap { entry -> String? in
            guard let name = entry.name, !name.isEmpty else { return nil }
            return name
        })
        allNames = uniqueNames.sorted()

        refreshShareStatus()
    }

    /// Prüft synchron, ob ein CKShare in einem der beiden Stores existiert.
    /// Da im Normalfall höchstens ein Share pro Store vorkommt, ist der synchrone
    /// Aufruf auf dem Main-Thread vertretbar.
    private func refreshShareStatus() {
        var shares: [CKShare] = []
        if let store = privateStore { shares += (try? container.fetchShares(in: store)) ?? [] }
        if let store = sharedStore  { shares += (try? container.fetchShares(in: store)) ?? [] }
        isShared = !shares.isEmpty
    }

    // MARK: - CRUD

    /// Gibt die Mahlzeit für einen bestimmten Tag zurück, oder nil wenn keiner existiert.
    /// Vergleich erfolgt per `isDate(_:inSameDayAs:)`, damit Uhrzeit-Unterschiede ignoriert werden.
    func meal(for date: Date) -> MealEntry? {
        meals.first { Calendar.current.isDate($0.date ?? .distantPast, inSameDayAs: date) }
    }

    /// Speichert einen Gerichtnamen für einen Tag. Existiert bereits ein Eintrag, wird
    /// `name` aktualisiert; sonst wird ein neuer MealEntry angelegt.
    func save(name: String, for date: Date) {
        let ctx = container.viewContext
        if let existing = meal(for: date) {
            existing.name = name
        } else {
            let entry = MealEntry(context: ctx)
            entry.id = UUID()
            entry.date = date
            entry.name = name
        }
        persist()
    }

    /// Löscht den Mahlzeiteintrag für den angegebenen Tag, falls vorhanden.
    func delete(for date: Date) {
        guard let entry = meal(for: date) else { return }
        container.viewContext.delete(entry)
        persist()
    }

    /// Speichert ausstehende Änderungen in den Persistent Store und löst danach
    /// einen neuen Fetch aus, um die @Published-Properties zu aktualisieren.
    /// Der anschließende Remote-Change-Observer würde ebenfalls einen Fetch auslösen,
    /// aber nur bei tatsächlichen CloudKit-Roundtrips – der direkte fetch()-Aufruf
    /// hier sorgt für sofortige lokale Konsistenz.
    private func persist() {
        guard container.viewContext.hasChanges else { return }
        do {
            try container.viewContext.save()
        } catch {
            print("⚠️ Speicherfehler: \(error)")
        }
        fetch()
    }

    // MARK: - Sharing

    /// Bereitet einen CKShare für die Sharing-UI vor.
    ///
    /// Existiert bereits ein Share, wird `minimumAppVersion` gelöscht, damit
    /// TestFlight-Empfänger nicht durch einen App-Store-Versions-Check blockiert werden,
    /// und der bestehende Share wird zurückgegeben.
    ///
    /// Existiert noch kein Share, werden alle Mahlzeiten in einen neuen Share gepackt.
    /// Der Completion-Handler wird immer auf dem Main-Thread aufgerufen.
    func prepareShare(completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        guard let store = privateStore else { completion(nil, nil, nil); return }
        let ckContainer = CKContainer(identifier: "iCloud.eu.barann.speisewagen")

        if let existing = (try? container.fetchShares(in: store))?.first {
            existing["minimumAppVersion"] = nil
            let op = CKModifyRecordsOperation(recordsToSave: [existing])
            op.savePolicy = .changedKeys
            op.modifyRecordsResultBlock = { _ in
                DispatchQueue.main.async { completion(existing, ckContainer, nil) }
            }
            ckContainer.privateCloudDatabase.add(op)
            return
        }

        // Ohne mindestens einen Datensatz kann kein Share angelegt werden.
        guard !meals.isEmpty else {
            completion(nil, nil, NSError(
                domain: "MealStore", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Bitte füge zuerst mindestens ein Gericht hinzu."]))
            return
        }

        container.share(meals, to: nil) { _, share, ck, error in
            DispatchQueue.main.async {
                share?[CKShare.SystemFieldKey.title] = "Speisewagen – Wochenmenü"
                completion(share, ck, error)
            }
        }
    }

    /// Nimmt eine geteilte iCloud-Einladung an und importiert die Daten in den shared Store.
    /// Wird vom AppDelegate aufgerufen, wenn der Benutzer einen Share-Link öffnet.
    func acceptShare(metadata: CKShare.Metadata) {
        guard let sharedStore else {
            print("⚠️ acceptShare aufgerufen, bevor der shared Store bereit war")
            return
        }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { [weak self] _, error in
            if let error { print("⚠️ acceptShare-Fehler: \(error)") }
            // Auf Main-Thread wechseln, da fetch() @Published-Properties ändert.
            DispatchQueue.main.async { self?.fetch() }
        }
    }
}
