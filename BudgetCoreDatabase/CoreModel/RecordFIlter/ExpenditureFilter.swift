//
//  ExpenditureFilter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public final class ExpenditureFilter: AbstractTransactionFilter {
    public override init() {
    }
    
    public override func filter(_ items: [Transaction]) -> [Transaction] {
        var passedItems: [Transaction] = []
        for item in items {
            if item.category.transactionType == .expenditure {
                passedItems.append(item)
            }
        }
        return passedItems
    }
}
