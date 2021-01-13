//
//  AggregatedTransactionCollection.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/23.
//

import Cocoa

public struct AggregatedTransactionCollection {
    private var transactions: [AggregatedTransaction] = []
    
    public var cout: Int {
        return transactions.count
    }
    public var totalAmounts: [Int] {
        var total: [Int] = []
        for transaction in transactions {
            total.append(transaction.totalAmounts)
        }
        return total
    }
    public var breakdown: [BreakdownStorage] {
        var total: [BreakdownStorage] = []
        for transaction in transactions {
            total.append(transaction.breakdown)
        }
        return total
    }
    
    mutating func append(_ element: AggregatedTransaction) {
        transactions.append(element)
    }
}
