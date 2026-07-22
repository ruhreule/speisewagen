import CoreData

/// CoreData-Entität für ein Rezept.
/// Das Modell wird programmatisch in MealStore.makeModel() definiert.
@objc(Recipe)
public class Recipe: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var instructions: String?
    /// JPEG-komprimiertes Foto, extern gespeichert (allowsExternalBinaryDataStorage = true).
    @NSManaged public var imageData: Data?
    /// Erstellungsdatum, dient als Sortierschlüssel (neueste zuerst).
    @NSManaged public var createdAt: Date?
    /// Anzahl der Personen/Portionen. CoreData-Default: 4 (gesetzt in makeModel()).
    @NSManaged public var servings: Int16
    /// Ungeordnetes Set aller zugehörigen RecipeIngredient-Objekte.
    /// Wird per Cascade-Delete-Regel beim Löschen des Rezepts automatisch mitgelöscht.
    @NSManaged public var ingredientItems: NSSet?

    /// Zutatenliste aufsteigend nach sortOrder sortiert.
    var sortedIngredients: [RecipeIngredient] {
        (ingredientItems?.allObjects as? [RecipeIngredient] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension Recipe: Identifiable {}
