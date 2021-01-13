//
//  Sorter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public enum SortDirection {
    case ascending
    case discending
}
public protocol SorterProtocol {
    var direction: SortDirection { get }
    
    func sort<T>(items: [T]) -> [T] where T: Comparable
    func sort<T, U>(items: [U], _ reference: (U) -> T) -> [U] where T: Comparable
}
