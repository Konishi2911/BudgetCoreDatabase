//
//  TransactionCategoryProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/11.
//

import Cocoa

public protocol TransactionCategoryProtocol {
    var categoryItemsDictionary: KeyIndexableKeyValuePairs<String, TransactionCategoryProtocol> { get }
    
    var categoryNames: [String] { get }
    var subCategories: [TransactionCategoryProtocol] { get }
    
    func isValid(categoryName: String...) -> Bool
    func isValid(categoryNamesArray: [String]) -> Bool
    func getCategoryArray(categoryNamesArray: [String]) -> [TransactionCategoryProtocol]
}

extension TransactionCategoryProtocol {
    public var categoryNames: [String] {
        let _keys = categoryItemsDictionary.keys
        return [String](_keys)
    }
    public var subCategories: [TransactionCategoryProtocol] {
        let _values = categoryItemsDictionary.values
        return [TransactionCategoryProtocol](_values)
    }

    
    public func isValid(categoryName: String...) -> Bool {
        isValid(categoryNamesArray: categoryName)
    }
    public func isValid(categoryNamesArray: [String]) -> Bool {
        guard let rootCategoryName = categoryNamesArray.first else {
            return false
        }
        if !self.categoryItemsDictionary.keys.contains(rootCategoryName) {
            return false
        }
        
        var category: TransactionCategoryProtocol = self
        for name in categoryNamesArray {
            guard let _category = category.categoryItemsDictionary[name] else {
                return false
            }
            category = _category
        }
        return true
    }
    public func getCategoryArray(categoryNamesArray: [String]) -> [TransactionCategoryProtocol] {
        var categories: [TransactionCategoryProtocol] = []
        if !self.categoryItemsDictionary.keys.contains(categoryNamesArray.first!) {
            return []
        }
        
        var category: TransactionCategoryProtocol = self
        for name in categoryNamesArray {
            guard let _category = category.categoryItemsDictionary[name] else {
                break
            }
            categories.append(category)
            category = _category
        }
        return categories
    }

}
