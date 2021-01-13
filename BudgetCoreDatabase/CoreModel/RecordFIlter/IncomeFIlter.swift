//
//  IncomeFIlter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public final class IncomeFilter: AbstractTransactionFilter {
    public override init() {
    }
    
    public override func filter(_ items: [Transaction]) -> [Transaction] {
        var passedItems: [Transaction] = []
        for item in items {
            if item.category.transactionType == .income {
                passedItems.append(item)
            }
        }
        return passedItems
    }
}
