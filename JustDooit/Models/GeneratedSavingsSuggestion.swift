import FoundationModels

@Generable(description: "Everyday spending habits based on the supplied summary. Use the language requested in the instructions.")
struct GeneratedSavingsSuggestion {
    @Guide(description: "One short sentence naming the largest recorded category. No claims about recurrence, trends or individual days. No figures, amounts, percentages or new budget status.")
    var summary: String
    @Guide(description: "Two or three practical actions relevant to the category and status. No numbers, calculations, investment products, loans or assumptions about income.", .count(2...3))
    var actions: [String]
}
