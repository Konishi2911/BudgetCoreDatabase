//
//  BreakdownItem.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/24.
//

import Cocoa

public struct BreakdownStorage: ExpressibleByDictionaryLiteral, Collection {

    public typealias Index = Int
    public typealias Element = (String, Int)
    
    public typealias Key = String
    public typealias Value = Int
    
    private(set) var keys: [Key] = []
    private(set) var values: [Value] = []
    
    public var count: Int { keys.count }
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        for tuple in elements {
            assert(!keys.contains(tuple.0))
            
            self.keys.append(tuple.0)
            self.values.append(tuple.1)
        }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            guard self.keys.contains(key) else { return nil }
            
            let index = self.keys.firstIndex(of: key)!
            return self.values[index]
        }
        set(value) {
            if self.keys.contains(key) {
                let index = self.keys.firstIndex(of: key)!
                self.values[index] = value!
            } else {
                self.keys.append(key)
                self.values.append(value!)
            }
        }
    }
    
    // MARK: - Collections
    public var startIndex: Int { 0 }
    public var endIndex: Int { self.count }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
    
    public subscript(position: Int) -> (String, Int) {
        precondition(position < self.count)
        
        return (self.keys[position], self.values[position])
    }
}
