import FoundationModels

@Generable(description: "The short name of a shared bill.")
struct GeneratedBillTitle {
    @Guide(description: "Two to five words copied exactly from the user's sentence, for example 'lunch at Hoka'. Drop filler such as 'the bill name is' or 'call it'.")
    var title: String
}
