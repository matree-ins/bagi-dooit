import Foundation

@MainActor
enum SiriRegressionChecks {
    static func run(store: ExpenseStore) async throws -> Int {
        var count = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label)
            count += 1
            print("PASS: \(label)")
        }
        func rejects(_ action: () throws -> Void) -> Bool {
            do { try action(); return false } catch { return true }
        }
        for (spoken, expected) in [("25.000", 25000), ("25,000", 25000), ("dua puluh lima ribu", 25000),
                                    ("twenty five thousand", 25000), ("seratus lima ribu", 105000),
                                    ("dua juta tiga ratus lima puluh ribu", 2350000), ("Rp 25.000", 25000)] {
            check(try SiriSpokenNumber.integer(spoken) == expected, "Spoken rupiah parsed: \(spoken)")
        }
        for input in ["dua tiga", "2.5", "-100", "infinity", "25 dollars", "two thousand thousand"] {
            check(rejects { _ = try SiriSpokenNumber.integer(input) }, "Ambiguous or invalid number rejected: \(input)")
        }
        let items = try SiriBillParser.items("nasi goreng jumlah dua harga satuan dua puluh lima ribu lalu es teh jumlah tiga harga satuan lima ribu")
        check(items.count == 2 && items[0].quantity == 2 && items[0].unitPrice == 25000, "Item quantities and unit prices are preserved")
        check(try SiriBillParser.items("fried rice quantity two unit price twenty five thousand").first?.total == 50000, "English structured item grammar is supported")
        check(try SiriBillParser.items("kopi 2 x 25.000").first?.total == 50000, "Compact numeric item grammar is supported")
        for input in ["kopi", "kopi 0 x 1000", "kopi 2 x -1000", "kopi 2 x 0", "kopi 100 x 1", "kopi 1 x 5000 lalu KOPI 1 x 6000", "kopi 99 x 1000000000"] {
            check(rejects { _ = try SiriBillParser.items(input) }, "Invalid or duplicate item rejected: \(input)")
        }
        let people = try SiriEntryValidator.participants("Saya, Budi dan Siti")
        check(people.map(\.name) == ["Saya", "Budi", "Siti"], "Owner is included once and manual participant names are retained")
        for input in ["Budi, budi", "Saya", "Saya, aku, Budi", "Budi,,Siti", "Budi 2"] {
            check(rejects { _ = try SiriEntryValidator.participants(input) }, "Ambiguous participant list rejected: \(input)")
        }
        let allocations = try SiriBillParser.assignments("nasi goreng untuk Budi satu dan Siti satu lalu es teh untuk Saya satu dan Budi satu dan Siti satu", items: items, participants: people)
        check(allocations.count == 5 && allocations.reduce(0) { $0 + $1.totalPrice } == 65000, "Each participant gets the specified item quantities")
        for input in ["nasi goreng untuk Budi satu lalu es teh untuk Saya", "nasi goreng untuk OrangAsing lalu es teh untuk Saya", "nasi goreng untuk Budi satu dan Siti lalu es teh untuk Saya", "nasi goreng untuk Budi dan Budi lalu es teh untuk Saya", "nasi goreng untuk Budi"] {
            check(rejects { _ = try SiriBillParser.assignments(input, items: items, participants: people) }, "Incomplete, mismatched or unknown allocations rejected")
        }
        let charges = try SiriBillParser.charges("pajak sepuluh persen lalu ongkir dua belas ribu lalu biaya admin tiga ribu lalu diskon lima ribu", subtotal: 65000)
        check(charges.charges.count == 3 && charges.discount == 5000, "Tax, delivery, arbitrary fees and discount are retained separately")
        check(try SiriBillParser.charges("tidak ada", subtotal: 65000).charges.isEmpty, "No extras does not invent taxes")
        check(try SiriBillParser.charges("pajak 2.5 persen", subtotal: 65000).charges.first?.value == 2.5, "Decimal tax percentages are supported")
        for input in ["diskon 70000", "pajak 101 persen", "ongkir -1000", "pajak 10 persen lalu pajak 5 persen", "ongkir abc", "diskon 1 lalu discount 2"] {
            check(rejects { _ = try SiriBillParser.charges(input, subtotal: 65000) }, "Invalid or duplicate fees rejected: \(input)")
        }
        let draft = try SiriSplitBillDraft(title: "Makan Siang", items: items, charges: charges, participants: people, assignedItems: allocations)
        check(draft.session.subtotal == 65000 && draft.session.additionalChargesTotal == 21000 && draft.session.total == 81000, "Tax is applied after discount, shipping and admin are fixed, total is exact")
        check(draft.session.taxPercentage == 0 && draft.session.servicePercentage == 0, "No default tax or service is charged twice")
        let shares = people.map { draft.session.participantTotal(for: $0.id) }
        check(shares.allSatisfy { $0.rounded() == $0 } && shares.reduce(0, +) == 81000, "Whole-rupiah participant shares sum exactly to the bill")
        check(shares == [6231, 37385, 37384], "Largest-remainder rounding is deterministic")
        check(draft.confirmationSummary.contains("nasi goreng") && draft.confirmationSummary.contains("ongkir") && draft.confirmationSummary.contains("Budi"), "Confirmation includes items, fees and named shares")
        let englishItems = try SiriBillParser.items("fried rice quantity two unit price twenty five thousand then iced tea quantity three unit price five thousand")
        let englishCharges = try SiriBillParser.charges("tax ten percent then delivery twelve thousand", subtotal: 65000)
        let englishPeople = try SiriEntryValidator.participants("Budi and Siti")
        let englishAllocations = try SiriBillParser.assignments("fried rice for Budi one and Siti one then iced tea for me one and Budi one and Siti one", items: englishItems, participants: englishPeople)
        let englishDraft = try SiriSplitBillDraft(title: "Lunch", items: englishItems, charges: englishCharges, participants: englishPeople, assignedItems: englishAllocations)
        check(englishDraft.session.total == 83500 && englishCharges.charges.count == 2, "English Siri answers produce the same split bill flow")
        for transcript in ["Fried rice quantity 2 unit price 25,000, then iced tea quantity 3 unit price 5,000.",
                           "Fried rice quantity two unit price $25,000. Then iced tea quantity three unit price $5000.",
                           "Fried rice, quantity 2, unit price 25,000 rupiah. Then iced tea, quantity 3, unit price 5,000 rupiah."] {
            let parsed = try? SiriBillParser.items(transcript)
            check(parsed?.map(\.name) == ["Fried rice", "iced tea"] && parsed?.map(\.total) == [50000, 15000], "Siri-style item transcript is parsed: \(transcript)")
        }
        let dictatedItems = try SiriBillParser.items("Fried rice quantity 2 unit price 25,000, then iced tea quantity 3 unit price 5,000.")
        let dictatedPeople = try SiriEntryValidator.participants("Budi and Siti.")
        check(dictatedPeople.map(\.name) == ["Saya", "Budi", "Siti"], "Dictated names drop the trailing period")
        let dictatedCharges = try SiriBillParser.charges("Tax 10%, then delivery $12,000.", subtotal: 65000)
        let dictatedNone = try SiriBillParser.charges("None.", subtotal: 65000)
        check(dictatedCharges.charges.count == 2 && dictatedNone.charges.isEmpty, "Dictated extras and None. are parsed")
        let dictatedAllocations = try SiriBillParser.assignments("Fried rice for Budi 1 and Siti 1, then iced tea for me 1, Budi 1 and Siti 1.", items: dictatedItems, participants: dictatedPeople)
        let dictatedDraft = try SiriSplitBillDraft(title: "Lunch.", items: dictatedItems, charges: dictatedCharges, participants: dictatedPeople, assignedItems: dictatedAllocations)
        check(dictatedDraft.session.title == "Lunch" && dictatedDraft.session.total == 83500, "A fully dictated Siri conversation produces the expected bill")
        check(try SiriBillParser.items("kopi 2 x Rp. 25.000").first?.total == 50000, "Indonesian Rp. abbreviation and dotted thousands still work")
        let modelItems = try SiriBillParser.items(SiriBillParser.itemText([("Fried rice", 2, 25000), ("Iced tea; extra", 3, 5000)]))
        check(modelItems.map(\.total) == [50000, 15000] && modelItems[1].name == "Iced tea  extra", "Model-extracted items pass the strict parser and cannot inject separators")
        check(rejects { _ = try SiriBillParser.items(SiriBillParser.itemText([("Kopi", 0, 5000)])) }, "Model-extracted zero quantity is still rejected")
        check(rejects { _ = try SiriBillParser.items(SiriBillParser.itemText([])) }, "Model returning no items is rejected")
        let modelCharges = try SiriBillParser.charges(SiriBillParser.chargeText([("tax", 2.5, true), ("delivery", 12000, false), ("discount", 5000, false)]), subtotal: 65000)
        check(modelCharges.charges.count == 2 && modelCharges.discount == 5000, "Model-extracted fees and discount pass the strict parser")
        check(try SiriBillParser.charges(SiriBillParser.chargeText([]), subtotal: 65000).charges.isEmpty, "Model returning no fees means none")
        for bad in [("tax", 150.0, true), ("delivery", 12000.5, false), ("delivery", Double.nan, false), ("delivery", -1, false)] {
            check(rejects { _ = try SiriBillParser.charges(SiriBillParser.chargeText([bad]), subtotal: 65000) }, "Invalid model fee is rejected: \(bad)")
        }
        let modelAllocations = try SiriBillParser.assignments(SiriBillParser.assignmentText([
            (item: "nasi goreng", shares: [(person: "Budi", portions: 1), (person: "Siti", portions: 1)]),
            (item: "es teh", shares: [(person: "Saya", portions: 0), (person: "Budi", portions: 0), (person: "Siti", portions: 0)])
        ]), items: items, participants: people)
        check(modelAllocations.count == 3 && modelAllocations.reduce(0) { $0 + $1.totalPrice } == 65000, "Model-extracted portions and equal sharing pass the strict parser")
        check(rejects { _ = try SiriBillParser.assignments(SiriBillParser.assignmentText([
            (item: "nasi goreng", shares: [(person: "Budi", portions: 5)]),
            (item: "es teh", shares: [(person: "OrangAsing", portions: 0)])
        ]), items: items, participants: people) }, "Model-invented people or wrong portions are rejected")
        let largeItem = try SiriBillParser.items("pizza jumlah sepuluh harga satuan seribu")
        let largeAllocation = try SiriBillParser.assignments("pizza untuk Budi sepuluh", items: largeItem, participants: people)
        check(largeAllocation.first?.quantity == 10, "Spoken quantities above nine work in allocations")
        let sharedAllocation = try SiriBillParser.assignments("nasi goreng untuk Saya dan Budi lalu es teh untuk Siti", items: items, participants: people)
        check(sharedAllocation[0].assignedParticipantIds.count == 2, "An entire item can be shared by named participants without explicit counts")
        check(rejects { _ = try SiriSplitBillDraft(title: "Free", items: items, charges: SiriBillCharges(discount: 65000), participants: people, assignedItems: allocations) }, "Zero final total is rejected before confirmation")
        check(rejects { _ = try SiriEntryValidator.amount(.infinity) }, "Nonfinite Siri expense is rejected")
        check(rejects { _ = try SiriEntryValidator.amount(12.5) }, "Fractional-rupiah expense is rejected")
        check(rejects { _ = try SiriEntryValidator.title(" ") }, "Blank Siri title is rejected")

        let oldCount = store.splitSessions.count
        do {
            try await SiriRecordingService.recordSplitBill(draft, store: store) { throw CancellationError() }
            preconditionFailure("Cancellation must propagate")
        } catch is CancellationError { }
        check(store.splitSessions.count == oldCount, "Declining Siri confirmation does not save a bill")
        let cancelledOperation = Task { @MainActor in
            try await SiriRecordingService.recordSplitBill(draft, store: store) {
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await cancelledOperation.value; preconditionFailure("Cancelled task must fail") }
        catch is CancellationError { }
        check(store.splitSessions.count == oldCount, "Task cancellation after confirmation does not persist a bill")
        try await SiriRecordingService.recordSplitBill(draft, store: store) {
            check(store.splitSessions.count == oldCount, "Nothing is saved before confirmation finishes")
        }
        check(store.splitSessions.first?.id == draft.session.id, "Confirmed Siri bill appears immediately in the observable app store")
        try await SiriRecordingService.recordSplitBill(draft, store: store) { }
        check(store.splitSessions.count == oldCount + 1, "Retrying the same confirmed draft does not duplicate it")
        let encoded = try JSONEncoder().encode(draft.session)
        let decoded = try JSONDecoder().decode(SplitBillSession.self, from: encoded)
        check(decoded.additionalCharges?.count == 3 && decoded.total == draft.session.total && decoded.roundsToWholeRupiah == true, "Named fees and rounding survive persistence")
        var legacyJSON = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacyJSON.removeValue(forKey: "additionalCharges")
        legacyJSON.removeValue(forKey: "roundsToWholeRupiah")
        let legacy = try JSONDecoder().decode(SplitBillSession.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        check(legacy.additionalCharges == nil && legacy.roundsToWholeRupiah == nil, "Old saved split bills decode without migration or data loss")
        let personal = Expense(title: "Kopi Siri", amount: 25000, category: .other, inputMethod: .voice)
        let expenseCount = store.expenses.count
        do {
            try await SiriRecordingService.recordExpense(personal, store: store) { throw CancellationError() }
            preconditionFailure("Cancellation must propagate")
        } catch is CancellationError { }
        check(store.expenses.count == expenseCount, "Cancelled personal expense is not saved")
        try await SiriRecordingService.recordExpense(personal, store: store) { }
        try await SiriRecordingService.recordExpense(personal, store: store) { }
        check(store.expenses.count == expenseCount + 1 && store.expenses.first?.inputMethod == .voice, "Confirmed Siri expense is saved once with voice origin")
        let badExpense = Expense(title: "Invalid", amount: .nan, category: .other)
        do { try await SiriRecordingService.recordExpense(badExpense, store: store) { preconditionFailure("Invalid expense cannot reach confirmation") } }
        catch { }
        check(store.expenses.count == expenseCount + 1, "Invalid expense cannot mutate app data")
        return count
    }
}
