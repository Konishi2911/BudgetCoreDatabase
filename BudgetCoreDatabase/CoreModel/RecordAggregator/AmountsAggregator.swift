//
//  ExpenditureAggregator.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public struct AmountsAggregator: RecordAggregatorProtocol {
    public typealias AggregatedValueType = Int
    public typealias RecortType = Transaction

    public func aggregate(_ refs: [Transaction]) -> Int {
        var exp = 0
        for ref in refs {
            exp += ref.amounts * ref.pieces
        }
        return exp
    }
}
