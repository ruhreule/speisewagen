import CoreData
import CloudKit
import SwiftUI

final class MealStore: ObservableObject {
    static let shared = MealStore()

    @Published var meals: [MealEntry] = []
    @Published var isShared = false

    let container: NSPersistentCloudKitContainer
    private var privateStore: NSPersistentStore?

    private init() {
        container = NSPersistentCloudKitContainer(name: "Speisewagen",
                                                  managedObjectModel: Self.makeModel())
        setup()
    }

    // MARK: - Model defined in code (no .xcdatamodeld file needed)

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "MealEntry"
        entity.managedObjectClassName = "MealEntry"   // matches @objc(MealEntry)

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

    private func setup() {
        let storeURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("speisewagen.sqlite")

        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber,
                       forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let ckOpts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.eu.barann.speisewagen")
        ckOpts.databaseScope = .private
        desc.cloudKitContainerOptions = ckOpts

        container.persistentStoreDescriptions = [desc]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { [weak self] storeDesc, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    print("⚠️ Store load error: \(error)")
                } else if let url = storeDesc.url {
                    self.privateStore = self.container
                        .persistentStoreCoordinator.persistentStore(for: url)
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

    func fetch() {
        let req = NSFetchRequest<MealEntry>(entityName: "MealEntry")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        meals = (try? container.viewContext.fetch(req)) ?? []
        refreshShareStatus()
    }

    private func refreshShareStatus() {
        guard let store = privateStore else { return }
        isShared = ((try? container.fetchShares(in: store)) ?? []).isEmpty == false
    }

    // MARK: - CRUD

    func meal(for date: Date) -> MealEntry? {
        meals.first { Calendar.current.isDate($0.date ?? .distantPast, inSameDayAs: date) }
    }

    var allNames: [String] {
        Array(Set(meals.compactMap { $0.name }.filter { !$0.isEmpty })).sorted()
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

    private func persist() {
        guard container.viewContext.hasChanges else { return }
        try? container.viewContext.save()
        fetch()
    }

    // MARK: - Sharing

    func prepareShare(completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        guard let store = privateStore else { completion(nil, nil, nil); return }

        if let existing = (try? container.fetchShares(in: store))?.first {
            completion(existing,
                       CKContainer(identifier: "iCloud.eu.barann.speisewagen"),
                       nil)
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
        print("Share invitation received – shared-database support coming in a future update.")
    }
}
