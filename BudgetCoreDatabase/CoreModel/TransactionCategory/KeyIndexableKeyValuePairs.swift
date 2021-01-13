//
//  CategorySubCategoryPairs.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/29.
//

import Cocoa

public struct KeyIndexableKeyValuePairs<K: Equatable, V>: ExpressibleByDictionaryLiteral {
    public typealias Key = K
    public typealias Value = V
    
    var keys: [K]
    var values: [V]
    
    public init(dictionaryLiteral elements: (K, V)...) {
        keys = [];
        values = [];
        
        for tuple in elements {
            keys.append(tuple.0)
            values.append(tuple.1)
        }
    }
    
    public var count: Int {
        keys.count
    }
    public var first: (Key, Value)? {
        guard self.count != 0 else { return nil }
        return (self.keys.first!, self.values.first!)
    }
    
    public subscript(key: Key) -> Value? {
        get {
            if let index = self.keys.firstIndex(of: key) {
                return self.values[index]
            } else { return nil }
        }
        set(value) {
            if let index = self.keys.firstIndex(of: key) {
                self.values[index] = value!
            } else {
                self.keys.append(key)
                self.values.append(value!)
            }
        }
    }
}
