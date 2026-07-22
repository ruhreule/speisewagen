import CoreData
import CloudKit
import SwiftUI

/// Zentraler Datenspeicher der App. Hält alle Mahlzeiten und Rezepte im Arbeitsspeicher,
/// vermittelt zwischen SwiftUI-Views und CoreData und steuert die iCloud-Synchronisation.
///
/// Als Singleton (`MealStore.shared`) wird die Instanz einmalig erzeugt und über
/// `@EnvironmentObject` in den View-Baum injiziert.
final class MealStore: ObservableObject {
    static let shared = MealStore()

    /// Alle gespeicherten Mahlzeiten, aufsteigend nach Datum sortiert.
    @Published var meals: [MealEntry] = []

    /// Deduplizierte, alphabetisch sortierte Liste aller jemals eingegebenen Gerichtnamen.
    /// Wird für Autocomplete-Vorschläge verwendet.
    @Published private(set) var allNames: [String] = []

    /// Zeigt an, ob mindestens ein aktiver CKShare existiert.
    @Published var isShared = false

    /// Alle Rezepte, neueste zuerst sortiert.
    @Published var recipes: [Recipe] = []

    let container: NSPersistentCloudKitContainer
    private var privateStore: NSPersistentStore?
    private var sharedStore: NSPersistentStore?

    private init() {
        container = NSPersistentCloudKitContainer(name: "Speisewagen",
                                                  managedObjectModel: Self.makeModel())
        setup()
    }

    // MARK: - Modell (kein .xcdatamodeld-File)

    /// Erstellt das CoreData-Modell programmgesteuert.
    /// Das vermeidet eine .xcdatamodeld-Ressource und hält alle Schemainformationen
    /// versionierbar im Code.
    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: MealEntry
        let mealEntity = NSEntityDescription()
        mealEntity.name = "MealEntry"
        mealEntity.managedObjectClassName = "MealEntry"

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"; idAttr.attributeType = .UUIDAttributeType; idAttr.isOptional = true

        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"; dateAttr.attributeType = .dateAttributeType; dateAttr.isOptional = true

        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"; nameAttr.attributeType = .stringAttributeType; nameAttr.isOptional = true

        mealEntity.properties = [idAttr, dateAttr, nameAttr]

        // MARK: Recipe
        let recipeEntity = NSEntityDescription()
        recipeEntity.name = "Recipe"
        // Muss mit @objc(Recipe) in Recipe.swift übereinstimmen.
        recipeEntity.managedObjectClassName = "Recipe"

        let rId = NSAttributeDescription()
        rId.name = "id"; rId.attributeType = .UUIDAttributeType; rId.isOptional = true

        let rTitle = NSAttributeDescription()
        rTitle.name = "title"; rTitle.attributeType = .stringAttributeType; rTitle.isOptional = true

        let rIngredients = NSAttributeDescription()
        rIngredients.name = "ingredients"; rIngredients.attributeType = .stringAttributeType; rIngredients.isOptional = true

        let rInstructions = NSAttributeDescription()
        rInstructions.name = "instructions"; rInstructions.attributeType = .stringAttributeType; rInstructions.isOptional = true

        let rImageData = NSAttributeDescription()
        rImageData.name = "imageData"; rImageData.attributeType = .binaryDataAttributeType; rImageData.isOptional = true
        // Fotos werden automatisch als externe Dateien neben dem SQLite-Store abgelegt
        // und von CloudKit als CKAsset synchronisiert. Hält die DB-Datei klein.
        rImageData.allowsExternalBinaryDataStorage = true

        let rCreatedAt = NSAttributeDescription()
        rCreatedAt.name = "createdAt"; rCreatedAt.attributeType = .dateAttributeType; rCreatedAt.isOptional = true

        recipeEntity.properties = [rId, rTitle, rIngredients, rInstructions, rImageData, rCreatedAt]

        model.entities = [mealEntity, recipeEntity]
        return model
    }

    // MARK: - Setup

    private func setup() {
        let baseURL = NSPersistentContainer.defaultDirectoryURL()

        let privateDesc = NSPersistentStoreDescription(
            url: baseURL.appendingPathComponent("speisewagen.sqlite"))
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDesc.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        // Lightweight Migration erlaubt den Schemasprung von einer älteren Store-Version
        // (ohne Recipe-Entity) auf die aktuelle. Neue Entities/Attribute sind immer
        // lightweight-migrierbar – CoreData inferiert das Mapping automatisch.
        privateDesc.shouldMigrateStoreAutomatically = true
        privateDesc.shouldInferMappingModelAutomatically = true
        let privateOpts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.eu.barann.speisewagen")
        privateOpts.databaseScope = .private
        privateDesc.cloudKitContainerOptions = privateOpts

        let sharedDesc = NSPersistentStoreDescription(
            url: baseURL.appendingPathComponent("speisewagen-shared.sqlite"))
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDesc.setOption(true as NSNumber,
                             forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        sharedDesc.shouldMigrateStoreAutomatically = true
        sharedDesc.shouldInferMappingModelAutomatically = true
        let sharedOpts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.eu.barann.speisewagen")
        sharedOpts.databaseScope = .shared
        sharedDesc.cloudKitContainerOptions = sharedOpts

        container.persistentStoreDescriptions = [privateDesc, sharedDesc]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { [weak self] storeDesc, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("⚠️ Store-Ladefehler: \(error)")
                } else if let url = storeDesc.url {
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

        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in self?.fetch() }
    }

    // MARK: - Fetch

    /// Liest Mahlzeiten und Rezepte aus dem viewContext und aktualisiert alle @Published-Properties.
    func fetch() {
        // Mahlzeiten
        let req = NSFetchRequest<MealEntry>(entityName: "MealEntry")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        meals = (try? container.viewContext.fetch(req)) ?? []

        let uniqueNames = Set(meals.compactMap { entry -> String? in
            guard let name = entry.name, !name.isEmpty else { return nil }
            return name
        })
        allNames = uniqueNames.sorted()

        // Rezepte: neueste zuerst, damit die Liste die Bearbeitungsreihenfolge widerspiegelt
        let recipeReq = NSFetchRequest<Recipe>(entityName: "Recipe")
        recipeReq.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        recipes = (try? container.viewContext.fetch(recipeReq)) ?? []

        refreshShareStatus()
    }

    private func refreshShareStatus() {
        var shares: [CKShare] = []
        if let store = privateStore { shares += (try? container.fetchShares(in: store)) ?? [] }
        if let store = sharedStore  { shares += (try? container.fetchShares(in: store)) ?? [] }
        isShared = !shares.isEmpty
    }

    // MARK: - Mahlzeiten-CRUD

    func meal(for date: Date) -> MealEntry? {
        meals.first { Calendar.current.isDate($0.date ?? .distantPast, inSameDayAs: date) }
    }

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

    func delete(for date: Date) {
        guard let entry = meal(for: date) else { return }
        container.viewContext.delete(entry)
        persist()
    }

    // MARK: - Rezept-CRUD

    /// Legt ein neues Rezept an oder aktualisiert ein bestehendes.
    /// `editing` nil → neues Rezept; non-nil → Aktualisierung des übergebenen Objekts.
    func saveRecipe(title: String, ingredients: String, instructions: String,
                    imageData: Data?, editing existing: Recipe? = nil) {
        let ctx = container.viewContext
        let recipe: Recipe
        if let existing {
            recipe = existing
        } else {
            recipe = Recipe(context: ctx)
            recipe.id = UUID()
            recipe.createdAt = Date()
        }
        recipe.title = title
        recipe.ingredients = ingredients
        recipe.instructions = instructions
        recipe.imageData = imageData
        persist()
    }

    func deleteRecipe(_ recipe: Recipe) {
        container.viewContext.delete(recipe)
        persist()
    }

    // MARK: - Persistenz

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

    func acceptShare(metadata: CKShare.Metadata) {
        guard let sharedStore else {
            print("⚠️ acceptShare aufgerufen, bevor der shared Store bereit war")
            return
        }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { [weak self] _, error in
            if let error { print("⚠️ acceptShare-Fehler: \(error)") }
            DispatchQueue.main.async { self?.fetch() }
        }
    }
}
