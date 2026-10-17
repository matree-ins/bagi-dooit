//
//  ExpenseModel.swift
//  JustDooit
//

import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Makanan & Minuman"
    case transport = "Transportasi"
    case shopping = "Belanja"
    case bills = "Tagihan & Utilitas"
    case entertainment = "Hiburan"
    case health = "Kesehatan"
    case other = "Lainnya"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .bills: return "bolt.fill"
        case .entertainment: return "gamecontroller.fill"
        case .health: return "cross.case.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .pink
        case .bills: return .purple
        case .entertainment: return .indigo
        case .health: return .red
        case .other: return .gray
        }
    }
}

enum ExpenseInputMethod: String, Codable {
    case manual = "Manual"
    case voice = "Suara"
    case receiptScanner = "Scan Struk"
    case splitBill = "Split Bill"

    var icon: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .voice: return "mic.fill"
        case .receiptScanner: return "camera.viewfinder"
        case .splitBill: return "person.2.fill"
        }
    }
}

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var note: String
    var inputMethod: ExpenseInputMethod
    var splitSessionId: UUID? = nil

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: ExpenseCategory,
        date: Date = Date(),
        note: String = "",
        inputMethod: ExpenseInputMethod = .manual,
        splitSessionId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.note = note
        self.inputMethod = inputMethod
        self.splitSessionId = splitSessionId
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, date, note, inputMethod, splitSessionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.category = try container.decode(ExpenseCategory.self, forKey: .category)
        self.date = try container.decode(Date.self, forKey: .date)
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.inputMethod = try container.decodeIfPresent(ExpenseInputMethod.self, forKey: .inputMethod) ?? .manual
        self.splitSessionId = try container.decodeIfPresent(UUID.self, forKey: .splitSessionId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encode(date, forKey: .date)
        try container.encode(note, forKey: .note)
        try container.encode(inputMethod, forKey: .inputMethod)
        try container.encodeIfPresent(splitSessionId, forKey: .splitSessionId)
    }
}

enum CurrencyFormatter {
    static func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp\(Int(amount))"
    }

    static func cleanNumberString(_ string: String) -> String {
        return string.filter { "0123456789".contains($0) }
    }
}
