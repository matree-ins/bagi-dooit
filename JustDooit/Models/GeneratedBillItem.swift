import FoundationModels

@Generable(description: "One ordered item on a restaurant bill, exactly as the user said it.")
struct GeneratedBillItem {
    @Guide(description: "Item name as spoken, for example fried rice or iced tea.")
    var name: String
    @Guide(description: "Number of portions ordered. Use 1 when the user did not say a quantity.")
    var quantity: Int
    @Guide(description: "Price of one portion in Indonesian rupiah as a whole number. 'k' or 'rb' means thousand, 'jt' means million, so 25k is 25000.")
    var unitPrice: Int
}
