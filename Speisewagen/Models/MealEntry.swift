import CoreData

@objc(MealEntry)
public class MealEntry: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var name: String?
}
