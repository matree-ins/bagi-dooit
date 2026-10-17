import FoundationModels

@Generable(description: "Every extra charge and discount the user mentioned.")
struct GeneratedBillCharges {
    @Guide(description: "Only charges the user said. Empty when the user said there are none.")
    var charges: [GeneratedBillCharge]
}
