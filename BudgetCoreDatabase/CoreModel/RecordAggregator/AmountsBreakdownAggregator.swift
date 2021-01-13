//
//  CategoryAggregator.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public struct AmountsBreakdownAggregator: RecordAggregatorProtocol {
    
    public func aggregate(_ refs: [Transaction]) -> BreakdownStorage {
        var breakdowns: BreakdownStorage = [:]
        for transaction in refs {
            if breakdowns[transaction.category.categoryNameSequence.first!] != nil {
                breakdowns[transaction.category.categoryNameSequence.first!]! += transaction.amounts * transaction.pieces
            } else {
                breakdowns[transaction.category.categoryNameSequence.first!]
                    = transaction.amounts * transaction.pieces
            }
        }
        return breakdowns
    }
}
