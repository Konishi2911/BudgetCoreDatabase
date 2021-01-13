//
//  RecordProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/08.
//

import Cocoa

/// A record that is data in table.
///
/// If there is the possibility that a table will contain multiple different implementation of record that conforms this,
/// the record should be class.
///
/// Because if it is struct, the record collection in table will be Extential Collection,
/// so that performance of the table may be decreased.
public protocol RecordProtocol: Equatable {
    
    /// An identifier of this record.
    /// This identifier ensure the record is unique in a table
    var id: UInt64? { get }
}

extension RecordProtocol {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.id != nil || rhs.id != nil else {
            return false
        }
        return lhs.id == rhs.id
    }
}
