//
//  TransactionType.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/12.
//

import Cocoa

public enum TransactionType: String, Codable {
    case income
    case expenditure
    
    public var categoryItemsProvider: TransactionCategoryProvider {
        switch self {
        case .income:
            return TransactionCategoryProvider.income
        case .expenditure:
            return TransactionCategoryProvider.payment
        }
    }
    public static func getCategory(type: TransactionType) -> TransactionCategoryProvider {
        switch type {
        case .income:
            return TransactionCategoryProvider.income
        case .expenditure:
            return TransactionCategoryProvider.payment
        }
    }
}
