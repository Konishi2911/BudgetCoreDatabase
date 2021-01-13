//
//  BubbleSorter.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public class BubbleSorter: SorterProtocol {
    public let direction: SortDirection
    
    public init(direction: SortDirection) {
        self.direction = direction
    }
    
    public func sort<T>(items: [T]) -> [T] where T : Comparable {
        return sort(items: items, {item in return item} )
    }
    
    public func sort<T, U>(items: [U], _ reference: (U) -> T) -> [U] where T: Comparable {
        guard items.count > 0 else { return Array<U>() }
        
        var sortedItems: [U] = items
        
        let size = sortedItems.count
        for i in 0..<(size - 1) {
            for j in 0..<(size - i - 1) {
                switch direction {
                case .ascending:
                    if reference(sortedItems[j]) > reference(sortedItems[j + 1]) {
                        sortedItems.swapAt(j, j + 1)
                    }
                case .discending:
                    if reference(sortedItems[j]) < reference(sortedItems[j + 1]) {
                        sortedItems.swapAt(j, j + 1)
                    }
                }
            }
        }
        return sortedItems
    }
}
