//
//  TransactionCategoryProvider.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/29.
//

import Cocoa

public struct TransactionCategoryProvider {
    public enum CategoryNameSearchingPolicy {
        case exactMatch
        case defaultWhenMissing
    }
    
    private var categoryDictionary: KeyIndexableKeyValuePairs<String, TransactionCategoryProvider>
    
    public var categoryNames: [String] {
        self.categoryDictionary.keys
    }
    public var isEmpty: Bool {
        self.categoryDictionary.count == 0
    }
    
    public func subCategory(_ name: String) -> TransactionCategoryProvider? {
        if let _sub = self.categoryDictionary[name] {
            guard !_sub.isEmpty else { return nil }
            return _sub
        } else { return nil }
    }
    
    public func isValid(categoryNamesArray: [String]) -> Bool {
        guard let rootCategoryName = categoryNamesArray.first else {
            if self.categoryDictionary.count == 0 { return true }
            else { return false }
        }
        guard let rootCategory = categoryDictionary[rootCategoryName] else { return false }
        
        let nextStringSequence = categoryNamesArray.filter{ $0 != rootCategoryName }
        return rootCategory.isValid(categoryNamesArray: nextStringSequence)
    }
    
    public var defaultNameSequence: [String] {
        self.getNameSequence(
            categoryNamesArray: [self.categoryNames.first!],
            policy: .defaultWhenMissing
        )
    }
    public func getNameSequence(categoryNamesArray: [String], policy: CategoryNameSearchingPolicy) -> [String] {
        return _getNameSequence(categoryNamesArray: categoryNamesArray, policy: policy)!
    }
    private func _getNameSequence(categoryNamesArray: [String], policy: CategoryNameSearchingPolicy) -> [String]? {
        var nameSequence: [String] = []
        guard let rootCategoryName = categoryNamesArray.first ?? self.categoryDictionary.first?.0 else { return nil }
        guard let subCategory = categoryDictionary[rootCategoryName] else { return nil }
        
        nameSequence.append(rootCategoryName)
        let nextStringSequence = categoryNamesArray.filter{ $0 != rootCategoryName }
        if let subNameSequence = subCategory._getNameSequence(
            categoryNamesArray: nextStringSequence, policy: policy) {
            nameSequence.append(contentsOf: subNameSequence)
        }
        return nameSequence
    }
    
    
    // MARK: Default Category Lists
    
    private static let empty = TransactionCategoryProvider(categoryDictionary: [:])
    static let income = TransactionCategoryProvider(
        categoryDictionary: [
            "Salary": empty,
            "Scholarship": empty,
            "Other": empty
        ])
    static let payment = TransactionCategoryProvider(
        categoryDictionary: [
            "Food": food,
            "Utilities": utilities,
            "Telecommunications": telecomunications,
            "Transportation": transportation,
            "Entertainment": entertainment,
            "DailyGoods": daily,
            "Medical": medical,
            "Home": home,
            "Education": education,
            "Other": empty
        ])
    private static let food = TransactionCategoryProvider(
        categoryDictionary: [
            "Groceries": empty,
            "Eating Out": empty,
            "Other": empty
        ])
    private static let utilities = TransactionCategoryProvider(
        categoryDictionary: [
            "Gas": empty,
            "Water": empty,
            "Electricity": empty
        ])
    private static let transportation = TransactionCategoryProvider(
        categoryDictionary: [
            "Train": empty,
            "Taxi": empty,
            "Bus": empty,
            "Airlines": empty,
            "Other": empty
        ])
    private static let telecomunications = TransactionCategoryProvider(
        categoryDictionary: [
            "Internet": empty,
            "Cell Phone": empty,
            "Stamps": empty,
            "Delivery": empty
        ])
    private static let entertainment = TransactionCategoryProvider(
        categoryDictionary: [
            "Hobby": empty,
            "Books": empty,
            "Musics": empty,
            "Other": empty
        ])
    private static let daily = TransactionCategoryProvider(
        categoryDictionary: [
            "Consumable": empty,
            "Detergents": empty,
            "Other": empty
        ])
    private static let medical = TransactionCategoryProvider(
        categoryDictionary: [
            "Hospital": empty,
            "Prescription": empty,
            "Other": empty
        ])
    private static let home = TransactionCategoryProvider(
        categoryDictionary: [
            "Rent": empty,
            "Furniture": empty,
            "Other": empty
        ])
    private static let education = TransactionCategoryProvider(
        categoryDictionary: [
            "Tuition": empty,
            "Reference Book": empty,
            "Examination Fee": empty,
            "Other": empty
        ])
}
