//
//  RecordFilterProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/08.
//

import Cocoa

public protocol RecordFilterProtocol {
    associatedtype RecordType: RecordProtocol
    
    func filter(_ items: [RecordType]) -> [RecordType]
}
