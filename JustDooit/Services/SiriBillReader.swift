import Foundation
import FoundationModels

/// Reads Siri answers with the strict grammar first. Only when that fails does the on-device model
/// rewrite free-form speech into the grammar, so validation and the spoken confirmation never change.
enum SiriBillReader {
    static func title(_ text: String) async throws -> String {
        let spoken = try SiriEntryValidator.title(text)
        guard spoken.split(whereSeparator: \.isWhitespace).count > 5,
              let extracted = await extract(spoken, as: GeneratedBillTitle.self, instructions: """
                You shorten the name a user gave to a shared bill. Copy the words from the user's sentence; never add words.
                """),
              let title = try? SiriEntryValidator.title(extracted.title),
              wasSpoken([title], in: spoken) else { return spoken }
        return title
    }

    static func items(_ text: String) async throws -> [SiriReceiptItem] {
        do { return try SiriBillParser.items(text) } catch {
            guard let extracted = await extract(text, as: GeneratedBillItems.self, instructions: """
                You convert a spoken restaurant bill into ordered items. Amounts are Indonesian rupiah.
                "Two fried rice at twenty five thousand each" is fried rice, quantity 2, unit price 25000.
                Only list items the user said. Never invent items, quantities or prices.
                """), wasSpoken(extracted.items.map(\.name), in: text) else { throw error }
            return try SiriBillParser.items(SiriBillParser.itemText(
                extracted.items.map { ($0.name, $0.quantity, $0.unitPrice) }))
        }
    }

    static func charges(_ text: String, subtotal: Double) async throws -> SiriBillCharges {
        do { return try SiriBillParser.charges(text, subtotal: subtotal) } catch {
            guard let extracted = await extract(text, as: GeneratedBillCharges.self, instructions: """
                You list the extra charges and discounts on a bill: tax, service, delivery, admin fees or discounts.
                Amounts are Indonesian rupiah. Only list charges the user said. Never invent charges or amounts.
                """) else { throw error }
            return try SiriBillParser.charges(SiriBillParser.chargeText(
                extracted.charges.map { ($0.name, $0.value, $0.isPercentage) }), subtotal: subtotal)
        }
    }

    /// The strict list also accepts sentences such as "it was me with Budi" as one long name,
    /// so names longer than two words go through the model too.
    static func participants(_ text: String) async throws -> [SplitParticipant] {
        let strict = Result { try SiriEntryValidator.participants(text) }
        if case .success(let people) = strict,
           people.allSatisfy({ $0.name.split(whereSeparator: \.isWhitespace).count <= 2 }) { return people }
        guard let extracted = await extract(text, as: GeneratedParticipants.self, instructions: """
            You list the friends who joined a shared bill. The speaker is added automatically.
            Copy each name exactly as spoken. Never invent names.
            """), wasSpoken(extracted.names, in: text),
              let people = try? SiriEntryValidator.participants(SiriBillParser.nameText(extracted.names)) else { return try strict.get() }
        return people
    }

    static func assignments(_ text: String, items: [SiriReceiptItem],
                            participants: [SplitParticipant]) async throws -> [SplitItem] {
        do { return try SiriBillParser.assignments(text, items: items, participants: participants) } catch {
            guard let portions = await portions(text, items: items, participants: participants) else { throw error }
            let expanded = portions.flatMap { portion in
                portion.person == everyone ? participants.map { (item: portion.item, person: $0.name, portions: 0) } : [portion]
            }
            let byItem = Dictionary(grouping: expanded, by: \.item)
            let rows = items.compactMap { item in
                byItem[item.name].map { (item: item.name, shares: $0.map { (person: $0.person, portions: $0.portions) }) }
            }
            return try SiriBillParser.assignments(SiriBillParser.assignmentText(rows), items: items, participants: participants)
        }
    }

    private static let everyone = "Everyone"

    /// Item and person are enums built from the bill, so the model can only pick names that already exist.
    /// "Everyone" is expanded in code because the small model drops people when listing them all itself.
    private static func portions(_ text: String, items: [SiriReceiptItem],
                                 participants: [SplitParticipant]) async -> [(item: String, person: String, portions: Int)]? {
        let portion = DynamicGenerationSchema(name: "ItemPortion", description: "One person receiving one item.", properties: [
            .init(name: "item", schema: DynamicGenerationSchema(name: "ItemName", anyOf: items.map(\.name))),
            .init(name: "person", schema: DynamicGenerationSchema(name: "PersonName", anyOf: participants.map(\.name) + [everyone])),
            .init(name: "portions", description: "Portions this person gets when the user said a number. 0 when the item is shared without numbers.",
                  schema: DynamicGenerationSchema(type: Int.self))
        ])
        let root = DynamicGenerationSchema(name: "ItemPortions", properties: [
            .init(name: "portions", description: "One entry for every person and item they receive.",
                  schema: DynamicGenerationSchema(arrayOf: portion, maximumElements: 200))
        ])
        let itemList = items.map { "\($0.name) (quantity \($0.quantity))" }.joined(separator: "; ")
        guard let schema = try? GenerationSchema(root: root, dependencies: []),
              let content = await generate(text, schema: schema, maximumResponseTokens: 1_500, instructions: """
                You divide the items of a bill between people based only on what the user said.
                Items: \(itemList).
                People: \(participants.map(\.name).joined(separator: "; ")).
                Saya is the speaker: me, I, my and myself mean Saya.
                When an item is for everyone, all of us, we all or each of us, write one entry with person Everyone and portions 0.
                When the user names people for an item, give it only to those named people, one entry per person.
                When the user says how many each person gets, those numbers must add up to the item quantity.
                """),
              let entries = try? content.value([GeneratedContent].self, forProperty: "portions") else { return nil }
        return try? entries.map {
            (item: try $0.value(String.self, forProperty: "item"),
             person: try $0.value(String.self, forProperty: "person"),
             portions: try $0.value(Int.self, forProperty: "portions"))
        }
    }

    /// Rejects model output that names something the user never said.
    private static func wasSpoken(_ names: [String], in text: String) -> Bool {
        let spoken = SiriBillParser.key(text)
        return names.allSatisfy { !SiriBillParser.key($0).isEmpty && spoken.contains(SiriBillParser.key($0)) }
    }

    /// Returns nil when the model is unavailable or fails; callers then report the strict-grammar error,
    /// which tells the user the exact format to say.
    private static func extract<Content: Generable>(_ text: String, as type: Content.Type,
                                                    instructions: String) async -> Content? {
        guard let session = session(for: text, instructions: instructions) else { return nil }
        return try? await session.respond(to: text, generating: type, options: options(maximumResponseTokens: 600)).content
    }

    private static func generate(_ text: String, schema: GenerationSchema, maximumResponseTokens: Int,
                                 instructions: String) async -> GeneratedContent? {
        guard let session = session(for: text, instructions: instructions) else { return nil }
        return try? await session.respond(to: text, schema: schema, options: options(maximumResponseTokens: maximumResponseTokens)).content
    }

    private static func session(for text: String, instructions: String) -> LanguageModelSession? {
        guard SystemLanguageModel.default.isAvailable, !text.isEmpty, text.count <= 6_000 else { return nil }
        return LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
    }

    private static func options(maximumResponseTokens: Int) -> GenerationOptions {
        GenerationOptions(samplingMode: .greedy, maximumResponseTokens: maximumResponseTokens)
    }
}
