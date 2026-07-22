import CoreData

@objc(MealEntry)
public class MealEntry: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var name: String?
    /// Optionale Verknüpfung zu einem Rezept. Nil, wenn der Eintrag manuell ohne Rezeptwahl erzeugt wurde.
    @NSManaged public var recipeID: UUID?
}
