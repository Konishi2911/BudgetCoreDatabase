//
//  PeriodFilter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public final class PeriodFilter: AbstractTransactionFilter {
    
    let startDate: Date
    let endDate: Date
    
    public init(from _sd: Date, to _ed: Date) {
        startDate = _sd
        endDate = _ed
    }
    public init(for _duration: DateInterval) {
        startDate = _duration.start
        endDate = _duration.end
    }
    
    public override func filter(_ items: [Transaction]) -> [Transaction] {
        var passedItems: [Transaction] = []
        for item in items {
            if (startDate <= item.date && item.date < endDate) {
                passedItems.append(item)
            }
        }
        return passedItems
    }
}

extension PeriodFilter {
    public static var weekly: PeriodFilter {
        get {
            let calendar = Calendar.current
            let dateComp = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
            
            let startDate = calendar.date(from: dateComp)!
            let endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate)!
            
            return PeriodFilter(from: startDate, to: endDate)
        }
    }
}
