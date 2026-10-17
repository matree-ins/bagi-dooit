import FoundationModels

@Generable(description: "Who receives one item of the bill.")
struct GeneratedItemAssignment {
    @Guide(description: "Item name copied exactly from the supplied item list.")
    var item: String
    @Guide(description: "Everyone who receives this item.")
    var shares: [GeneratedItemShare]
}
