import CoreData

/// CoreData-Entität für eine einzelne Zutat eines Rezepts.
/// Jede Zutat gehört über die Beziehung `recipe` genau einem Rezept an.
/// Beim Löschen des Rezepts werden alle zugehörigen Zutaten per Cascade gelöscht.
@objc(RecipeIngredient)
public class RecipeIngredient: NSManagedObject {
    @NSManaged public var id: UUID?
    /// Freitext-Menge, z. B. "200", "1/2", "nach Bedarf"
    @NSManaged public var amount: String?
    /// Einheit aus IngredientInput.unitOptions, z. B. "g", "EL", "" (keine Einheit)
    @NSManaged public var unit: String?
    /// Name der Zutat, z. B. "Mehl", "Eier"
    @NSManaged public var name: String?
    /// Ganzzahliger Index für die Sortierreihenfolge innerhalb des Rezepts
    @NSManaged public var sortOrder: Int16
    @NSManaged public var recipe: Recipe?
}

extension RecipeIngredient: Identifiable {}

// MARK: - Eingabe-Hilfstyp

/// Transienter Wert-Typ für das Bearbeitungsformular und die Übergabe an MealStore.saveRecipe().
/// Lebt nur im Arbeitsspeicher und wird nie direkt in CoreData gespeichert.
struct IngredientInput: Identifiable {
    var id     = UUID()
    var amount = ""
    var unit   = ""
    var name   = ""

    /// Alle angebotenen Einheiten im Formular; leerer String = keine Einheit.
    static let unitOptions = [
        "", "g", "kg", "ml", "l",
        "EL", "TL",
        "Stück", "Prise", "Bund", "Zehe", "Scheibe",
        "Dose", "Pkg.", "Glas"
    ]
}
