//
//  CategoryFilter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public final class CategoryFilter: AbstractTransactionFilter {
    let targetCategory: TransactionCategoryValue
    
    public init(_ target: TransactionCategoryValue) {
        targetCategory = target
    }
    
    public override func filter(_ items: [Transaction]) -> [Transaction] {
        var passedItems: [Transaction] = []
        for item in items {
            if (targetCategory == item.category) {
                passedItems.append(item)
            }
        }
        return passedItems
    }
}
