//
//  MultiFilter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public final class MultiFilter: AbstractTransactionFilter {
    let filters: [AbstractTransactionFilter]
    
    public init(filters: AbstractTransactionFilter...) {
        self.filters = filters
    }
    
    public override func filter(_ items: [Transaction]) -> [Transaction] {
        var filteredRecords = items
        for filter in filters {
            filteredRecords = filter.filter(filteredRecords)
        }
                
        return filteredRecords
    }
}
