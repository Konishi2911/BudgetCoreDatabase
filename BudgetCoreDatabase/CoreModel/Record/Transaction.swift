//
//  Transaction.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/08.
//

import Cocoa

public struct Transaction: RecordProtocol {
    public typealias MoneyAmounts = Int
    
    public let id: UInt64?
    
    public let date: Date
    public var category: TransactionCategoryValue
    public let name: String
    public let pieces: Int
    public let amounts: MoneyAmounts
    public let remarks: String
    
    public init(date: Date, category: TransactionCategoryValue, name: String, pieces: Int, amounts: MoneyAmounts, remarks: String) {
        self.id = nil
        self.date = date
        self.category = category
        self.name = name
        self.pieces = pieces
        self.amounts = amounts
        self.remarks = remarks
    }
    internal init(_ id: UInt64, record: Transaction) {
        self.id = id
        self.date = record.date
        self.category = record.category
        self.name = record.name
        self.pieces = record.pieces
        self.amounts = record.amounts
        self.remarks = record.remarks
    }
}

internal extension Int {
    enum RoundingMode {
        case ceiling
        case floor
        case halfEven
    }
    
    init(_ value: Int, with taxRate: Double, roundingMode: RoundingMode) {
        switch roundingMode {
        case .ceiling:
            self.init(Int(ceil(Double(value) * (1.0 + taxRate))))
        case .floor:
            self.init(Int(floor(Double(value) * (1.0 + taxRate))))
        case .halfEven:
            self.init(Int(round(Double(value) * (1.0 + taxRate))))
        }
    }
}

extension Transaction: Codable {
    
}
