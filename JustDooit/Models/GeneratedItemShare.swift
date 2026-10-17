import FoundationModels

@Generable(description: "One person who receives part of an item.")
struct GeneratedItemShare {
    @Guide(description: "Person name copied exactly from the supplied people list.")
    var person: String
    @Guide(description: "Portions this person gets. Use 0 when the item is shared equally without numbers.")
    var portions: Int
}
