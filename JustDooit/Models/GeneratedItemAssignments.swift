import FoundationModels

@Generable(description: "How every item on the bill is divided between people.")
struct GeneratedItemAssignments {
    @Guide(description: "One entry per supplied item, using only what the user said.")
    var assignments: [GeneratedItemAssignment]
}
