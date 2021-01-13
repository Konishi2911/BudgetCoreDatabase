//
//  AbstractTransactionProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public class AbstractTransactionFilter: RecordFilterProtocol {
    public func filter(_ items: [Transaction]) -> [Transaction] {
        fatalError()
    }
}
