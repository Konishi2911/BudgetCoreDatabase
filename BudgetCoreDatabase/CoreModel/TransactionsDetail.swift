//
//  TransactionsInformation.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public struct TransactionsDetail {
    public enum UnitPeriod {
        case day
        case week
        case month
        case year
    }
    
    public let targetDuration: DateInterval
    public let unitPeriod: UnitPeriod
    
    private(set) public var dateLabels: [String] = []
    private(set) public var expenditure: AggregatedTransaction
    private(set) public var income: AggregatedTransaction
    private(set) public var expenditureByUnit: AggregatedTransactionCollection = .init()
    private(set) public var incomeByUnit: AggregatedTransactionCollection = .init()
    
    public init(_ ref: TransactionsTable, for duration: DateInterval, by unit: UnitPeriod) {
        targetDuration = duration
        unitPeriod = unit
        
        expenditure = AggregatedTransaction(type: .expenditure ,reference: ref, duration)
        income = AggregatedTransaction(type: .income, reference: ref, duration)
        
        var tempStartDate: Date = duration.start
        var tempEndDate: Date = duration.start
        
        while tempStartDate < duration.end {
            switch unit {
            case .day:
                tempEndDate = Calendar.current.date(byAdding: .day, value: 1, to: tempStartDate)!
            case .week:
                tempEndDate = Calendar.current.date(byAdding: .day, value: 7, to: tempStartDate)!
            case .month:
                tempEndDate = Calendar.current.date(byAdding: .month, value: 1, to: tempStartDate)!
            case .year:
                tempEndDate = Calendar.current.date(byAdding: .year, value: 1, to: tempStartDate)!
            }
            
            self.dateLabels.append(self._getDateLabel(date: tempStartDate,
                                                     unitPeriod: unit))
            self.expenditureByUnit.append(AggregatedTransaction(
                                    type: .expenditure,
                                    reference: ref,
                                    DateInterval(start: tempStartDate, end: tempEndDate)))
            self.incomeByUnit.append(AggregatedTransaction(
                                    type: .income,
                                    reference: ref,
                                    DateInterval(start: tempStartDate, end: tempEndDate)))

            tempStartDate = tempEndDate
        }
    }
    public init(_ ref: TransactionsTable, startFrom _sd: Date, to _ed: Date, by unit: UnitPeriod) {
        self.init(ref, for: DateInterval(start: _sd, end: _ed), by: unit)
    }
    
    private func _getDateLabel(date: Date, unitPeriod: UnitPeriod) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.locale = .current
        
        switch unitPeriod {
        case .day:
            dateFormatter.dateFormat = "dd"
        case .week:
            dateFormatter.dateFormat = "EEEE"
        case .month:
            dateFormatter.dateFormat = "MMM"
        case .year:
            dateFormatter.dateFormat = "yyyy"
        }
        return dateFormatter.string(from: date)
    }
}
