//
//  RecordAggregatorProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public protocol RecordAggregatorProtocol {
    associatedtype RecortType: RecordProtocol
    associatedtype AggregatedValueType
    
    func aggregate(_ refs: [RecortType]) -> AggregatedValueType
}
