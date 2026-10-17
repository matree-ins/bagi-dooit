import Foundation
import FoundationModels

/// Reads Siri answers with the strict grammar first. Only when that fails does the on-device model
/// rewrite free-form speech into the grammar, so validation and the spoken confirmation never change.
enum SiriBillReader {
    static func items(_ text: String) async throws -> [SiriReceiptItem] {
        do { return try SiriBillParser.items(text) } catch {
            guard let extracted = await extract(text, as: GeneratedBillItems.self, instructions: """
                You convert a spoken restaurant bill into ordered items. Amounts are Indonesian rupiah.
                Only list items the user said. Never invent items, quantities or prices.
                """) else { throw error }
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

    static func assignments(_ text: String, items: [SiriReceiptItem],
                            participants: [SplitParticipant]) async throws -> [SplitItem] {
        do { return try SiriBillParser.assignments(text, items: items, participants: participants) } catch {
            let itemList = items.map { "\($0.name) (quantity \($0.quantity))" }.joined(separator: "; ")
            let people = participants.map(\.name).joined(separator: "; ")
            guard let extracted = await extract(text, as: GeneratedItemAssignments.self, instructions: """
                You divide the items of a bill between people based only on what the user said.
                Items: \(itemList).
                People: \(people).
                Saya is the speaker. Give an item to Saya only when the user says me, I, my, myself, we, us, everyone or all for that item.
                When the user names people for an item, give it only to those named people.
                "Everyone", "all of us" or "we all" means every person listed.
                Copy item and person names exactly from these lists. Never invent people, items or portions.
                """) else { throw error }
            let rows = extracted.assignments.map { assignment in
                (item: assignment.item, shares: assignment.shares.map { (person: $0.person, portions: $0.portions) })
            }
            return try SiriBillParser.assignments(SiriBillParser.assignmentText(rows), items: items, participants: participants)
        }
    }

    /// Returns nil when the model is unavailable or fails; callers then report the strict-grammar error,
    /// which tells the user the exact format to say.
    private static func extract<Content: Generable>(_ text: String, as type: Content.Type,
                                                    instructions: String) async -> Content? {
        guard SystemLanguageModel.default.isAvailable, !text.isEmpty, text.count <= 6_000 else { return nil }
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        return try? await session.respond(to: text, generating: type,
                                          options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 600)).content
    }
}
