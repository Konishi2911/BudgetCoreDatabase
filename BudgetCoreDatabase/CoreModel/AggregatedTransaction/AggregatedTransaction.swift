//
//  AggregatedTransaction.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/23.
//

import Cocoa

public struct AggregatedTransaction {
    private let targetDuration: DateInterval
    
    public let totalAmounts: Int
    public let breakdown: BreakdownStorage
    
    public init(type: TransactionType, reference: TransactionsTable, _ duration: DateInterval) {
        targetDuration = duration
        
        var multiFilter: MultiFilter
        switch type {
        case .income:
            multiFilter =
                MultiFilter(filters: PeriodFilter(for: duration), IncomeFilter())
        case .expenditure:
            multiFilter =
                MultiFilter(filters: PeriodFilter(for: duration), ExpenditureFilter())
        }
        
        let targetTransactions = reference.getRecords(filteredBy: multiFilter)
        
        totalAmounts = AmountsAggregator().aggregate(targetTransactions)
        breakdown = AmountsBreakdownAggregator().aggregate(targetTransactions)
    }
}
