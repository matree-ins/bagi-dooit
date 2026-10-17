import FoundationModels

@Generable(description: "Every item the user mentioned, in the order spoken.")
struct GeneratedBillItems {
    @Guide(description: "Only items the user said. Never invent items, quantities or prices.")
    var items: [GeneratedBillItem]
}
