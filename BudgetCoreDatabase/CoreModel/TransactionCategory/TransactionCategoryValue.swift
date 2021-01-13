//
//  TransactionCategory.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/12.
//

import Cocoa

public struct TransactionCategoryValue: Equatable {
    
    public let transactionType: TransactionType
    public let categoryNameSequence: [String]
    
    public init?(type: TransactionType, categoryNames: [String]) {
        switch type {
        case .income:
            guard TransactionCategoryProvider.income.isValid(categoryNamesArray: categoryNames) else {
                return nil
            }
        case .expenditure:
            guard TransactionCategoryProvider.payment.isValid(categoryNamesArray: categoryNames) else {
                return nil
            }
        }
        self.transactionType = type
        self.categoryNameSequence = categoryNames
    }
 
    public static func == (lhs: TransactionCategoryValue, rhs: TransactionCategoryValue) -> Bool {
        return lhs.transactionType == rhs.transactionType &&
            lhs.categoryNameSequence == rhs.categoryNameSequence
    }
}

extension TransactionCategoryValue: Codable {
    enum CodingKeys: String, CodingKey {
        case transactionType
        case categoryNameSequence
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionType = try values.decode(TransactionType.self, forKey: .transactionType)
        
        let categoryProvider = TransactionType.getCategory(type: transactionType)
        let categoryNames = try values.decode(Array<String>.self, forKey: .categoryNameSequence)
        let nameSequence = categoryProvider.getNameSequence(
            categoryNamesArray: categoryNames,
            policy: .defaultWhenMissing
        ) 
        self.categoryNameSequence = nameSequence
    }
}
