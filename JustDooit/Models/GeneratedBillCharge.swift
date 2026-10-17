import FoundationModels

@Generable(description: "One extra charge or discount on a bill, such as tax, service, delivery, admin fee or discount.")
struct GeneratedBillCharge {
    @Guide(description: "Short charge name as spoken, for example tax, service, delivery or admin. Name any discount exactly 'discount'.")
    var name: String
    @Guide(description: "The number the user said for this charge: the percentage itself, or the rupiah amount as a whole number. 'k' or 'rb' means thousand.")
    var value: Double
    @Guide(description: "True only if the user said 'percent', 'persen' or '%' for this charge, for example 'ten percent tax'. False for rupiah amounts.")
    var isPercentage: Bool
}
