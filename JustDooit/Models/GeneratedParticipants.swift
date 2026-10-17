import FoundationModels

@Generable(description: "The friends who joined a shared bill.")
struct GeneratedParticipants {
    @Guide(description: "Each friend's name copied exactly as spoken. Leave out the speaker: me, I, myself, Saya.")
    var names: [String]
}
