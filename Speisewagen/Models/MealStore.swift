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
    // Vom NSPersistentCloudKitContainer geliefert – nie selbst instanziieren, da sonst
    // ein Environment-Konflikt (Sandbox vs. Production) zu einem NSException-Crash führt.
    private var cachedCKContainer: CKContainer?

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

        let recipeIDAttr = NSAttributeDescription()
        recipeIDAttr.name = "recipeID"; recipeIDAttr.attributeType = .UUIDAttributeType; recipeIDAttr.isOptional = true

        mealEntity.properties = [idAttr, dateAttr, nameAttr, recipeIDAttr]

        // MARK: Recipe
        let recipeEntity = NSEntityDescription()
        recipeEntity.name = "Recipe"
        // Muss mit @objc(Recipe) in Recipe.swift übereinstimmen.
        recipeEntity.managedObjectClassName = "Recipe"

        let rId = NSAttributeDescription()
        rId.name = "id"; rId.attributeType = .UUIDAttributeType; rId.isOptional = true

        let rTitle = NSAttributeDescription()
        rTitle.name = "title"; rTitle.attributeType = .stringAttributeType; rTitle.isOptional = true

        let rInstructions = NSAttributeDescription()
        rInstructions.name = "instructions"; rInstructions.attributeType = .stringAttributeType; rInstructions.isOptional = true

        let rImageData = NSAttributeDescription()
        rImageData.name = "imageData"; rImageData.attributeType = .binaryDataAttributeType; rImageData.isOptional = true
        // Fotos werden automatisch als externe Dateien neben dem SQLite-Store abgelegt
        // und von CloudKit als CKAsset synchronisiert. Hält die DB-Datei klein.
        rImageData.allowsExternalBinaryDataStorage = true

        let rCreatedAt = NSAttributeDescription()
        rCreatedAt.name = "createdAt"; rCreatedAt.attributeType = .dateAttributeType; rCreatedAt.isOptional = true

        let rServings = NSAttributeDescription()
        rServings.name = "servings"; rServings.attributeType = .integer16AttributeType; rServings.isOptional = false
        rServings.defaultValue = 4 as NSNumber

        recipeEntity.properties = [rId, rTitle, rInstructions, rImageData, rCreatedAt, rServings]

        // MARK: RecipeIngredient
        let ingredientEntity = NSEntityDescription()
        ingredientEntity.name = "RecipeIngredient"
        ingredientEntity.managedObjectClassName = "RecipeIngredient"

        let iId = NSAttributeDescription()
        iId.name = "id"; iId.attributeType = .UUIDAttributeType; iId.isOptional = true

        let iAmount = NSAttributeDescription()
        iAmount.name = "amount"; iAmount.attributeType = .stringAttributeType; iAmount.isOptional = true

        let iUnit = NSAttributeDescription()
        iUnit.name = "unit"; iUnit.attributeType = .stringAttributeType; iUnit.isOptional = true

        let iName = NSAttributeDescription()
        iName.name = "name"; iName.attributeType = .stringAttributeType; iName.isOptional = true

        let iSortOrder = NSAttributeDescription()
        iSortOrder.name = "sortOrder"; iSortOrder.attributeType = .integer16AttributeType; iSortOrder.isOptional = false
        iSortOrder.defaultValue = 0 as NSNumber

        ingredientEntity.properties = [iId, iAmount, iUnit, iName, iSortOrder]

        // Beziehung: Recipe → [RecipeIngredient] (to-many, cascade)
        let recipeToIngredients = NSRelationshipDescription()
        recipeToIngredients.name = "ingredientItems"
        recipeToIngredients.destinationEntity = ingredientEntity
        recipeToIngredients.minCount = 0
        recipeToIngredients.maxCount = 0           // unbegrenzt
        recipeToIngredients.deleteRule = .cascadeDeleteRule  // Zutaten mit Rezept löschen

        // Beziehung: RecipeIngredient → Recipe (to-one, nullify)
        let ingredientToRecipe = NSRelationshipDescription()
        ingredientToRecipe.name = "recipe"
        ingredientToRecipe.destinationEntity = recipeEntity
        ingredientToRecipe.minCount = 0
        ingredientToRecipe.maxCount = 1
        ingredientToRecipe.deleteRule = .nullifyDeleteRule

        // Inverse verknüpfen – CoreData erfordert beidseitige Inverse
        recipeToIngredients.inverseRelationship = ingredientToRecipe
        ingredientToRecipe.inverseRelationship = recipeToIngredients

        recipeEntity.properties.append(recipeToIngredients)
        ingredientEntity.properties.append(ingredientToRecipe)

        model.entities = [mealEntity, recipeEntity, ingredientEntity]
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

        // Ohne .xcdatamodeld-Datei kann CoreData neue Entities nicht automatisch migrieren.
        // Inkompatible Stores werden daher per FileManager gelöscht, damit loadPersistentStores
        // einen neuen Store anlegt. CloudKit synchronisiert die Daten anschließend zurück.
        let model = container.managedObjectModel
        let fm = FileManager.default
        for desc in [privateDesc, sharedDesc] {
            guard let url = desc.url, fm.fileExists(atPath: url.path) else { continue }
            if let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: url, options: nil),
               !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                for suffix in ["", "-wal", "-shm"] {
                    try? fm.removeItem(at: url.deletingLastPathComponent()
                        .appendingPathComponent(url.lastPathComponent + suffix))
                }
                print("ℹ️ Inkompatibles Schema – Store gelöscht: \(url.lastPathComponent)")
            }
        }

        container.persistentStoreDescriptions = [privateDesc, sharedDesc]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { [weak self] storeDesc, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("⚠️ Store-Ladefehler: \(error)")
                    // Fallback: Store-Dateien löschen und direkt am Coordinator anlegen
                    // (ohne CloudKit für diese Sitzung – Sync ab nächstem Start).
                    if let url = storeDesc.url {
                        for suffix in ["", "-wal", "-shm"] {
                            try? fm.removeItem(at: url.deletingLastPathComponent()
                                .appendingPathComponent(url.lastPathComponent + suffix))
                        }
                        let opts: [AnyHashable: Any] = [
                            NSPersistentHistoryTrackingKey: true as NSNumber,
                            NSPersistentStoreRemoteChangeNotificationPostOptionKey: true as NSNumber
                        ]
                        if let store = try? self.container.persistentStoreCoordinator
                            .addPersistentStore(ofType: NSSQLiteStoreType,
                                               configurationName: nil,
                                               at: url, options: opts) {
                            if storeDesc.cloudKitContainerOptions?.databaseScope == .shared {
                                self.sharedStore = store
                            } else {
                                self.privateStore = store
                            }
                            print("✓ Store lokal wiederhergestellt")
                        }
                    }
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
        ) { [weak self] _ in
            self?.fetch()
            self?.clearShareMinimumVersions()
        }
    }

    // Löscht minimumAppVersion von allen existierenden Shares.
    // Läuft nur wenn cachedCKContainer gesetzt ist (nach erstem prepareShare-Aufruf),
    // da CKContainer(identifier:) einen Production/Sandbox-Konflikt auslösen würde.
    private func clearShareMinimumVersions() {
        guard let ckContainer = cachedCKContainer,
              let store = privateStore,
              let shares = try? container.fetchShares(in: store),
              !shares.isEmpty else { return }

        shares.forEach { $0["minimumAppVersion"] = nil }
        let saveOp = CKModifyRecordsOperation(recordsToSave: shares)
        saveOp.savePolicy = .allKeys
        saveOp.qualityOfService = .utility
        saveOp.modifyRecordsResultBlock = { result in
            switch result {
            case .success: print("✓ minimumAppVersion von \(shares.count) Share(s) geleert")
            case .failure(let error): print("⚠️ clearShareMinimumVersions: \(error)")
            }
        }
        ckContainer.privateCloudDatabase.add(saveOp)
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

    func save(name: String, recipeID: UUID? = nil, for date: Date) {
        let ctx = container.viewContext
        if let existing = meal(for: date) {
            existing.name = name
            existing.recipeID = recipeID
        } else {
            let entry = MealEntry(context: ctx)
            entry.id = UUID()
            entry.date = date
            entry.name = name
            entry.recipeID = recipeID
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
    /// Alle alten RecipeIngredient-Objekte werden ersetzt – einfacher als Diff-Logik,
    /// bei typisch ≤ 20 Zutaten vernachlässigbarer Overhead.
    func saveRecipe(title: String, servings: Int16, ingredients: [IngredientInput],
                    instructions: String, imageData: Data?, editing existing: Recipe? = nil) {
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
        recipe.servings = servings
        recipe.instructions = instructions
        recipe.imageData = imageData

        // Alte Zutaten entfernen
        if let oldItems = recipe.ingredientItems {
            oldItems.forEach { ctx.delete($0 as! NSManagedObject) }
        }

        // Neue Zutaten anlegen; leere Zeilen werden übersprungen
        for (index, input) in ingredients.enumerated() {
            let trimmedName = input.name.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else { continue }
            let ingredient = RecipeIngredient(context: ctx)
            ingredient.id = UUID()
            ingredient.amount = input.amount.trimmingCharacters(in: .whitespaces)
            ingredient.unit = input.unit
            ingredient.name = trimmedName
            ingredient.sortOrder = Int16(index)
            ingredient.recipe = recipe
        }

        persist()
    }

    func deleteRecipe(_ recipe: Recipe) {
        container.viewContext.delete(recipe)
        persist()
    }

    // MARK: - Persistenz

    private func persist() {
        guard !container.persistentStoreCoordinator.persistentStores.isEmpty else {
            print("⚠️ persist() übersprungen: kein Store geladen")
            return
        }
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

        if let existing = (try? container.fetchShares(in: store))?.first {
            // container.share liefert den korrekten CKContainer ohne CKContainer(identifier:)
            // aufzurufen – das verhindert den Production/Sandbox-Environment-Crash.
            container.share(meals, to: existing) { [weak self] _, _, ckContainer, _ in
                DispatchQueue.main.async {
                    guard let self, let ckContainer else {
                        completion(existing, self?.cachedCKContainer, nil)
                        return
                    }
                    self.cachedCKContainer = ckContainer
                    existing["minimumAppVersion"] = nil
                    let saveOp = CKModifyRecordsOperation(recordsToSave: [existing])
                    saveOp.savePolicy = .allKeys
                    saveOp.qualityOfService = .userInitiated
                    saveOp.modifyRecordsResultBlock = { result in
                        if case .failure(let error) = result {
                            print("⚠️ prepareShare: \(error)")
                        }
                        DispatchQueue.main.async { completion(existing, ckContainer, nil) }
                    }
                    ckContainer.privateCloudDatabase.add(saveOp)
                }
            }
            return
        }

        guard !meals.isEmpty else {
            completion(nil, nil, NSError(
                domain: "MealStore", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Bitte füge zuerst mindestens ein Gericht hinzu."]))
            return
        }

        container.share(meals, to: nil) { [weak self] _, share, ckContainer, error in
            DispatchQueue.main.async {
                self?.cachedCKContainer = ckContainer
                share?[CKShare.SystemFieldKey.title] = "Speisewagen – Wochenmenü"
                completion(share, ckContainer, error)
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
