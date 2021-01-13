//
//  TableProtocol.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/08.
//

import Cocoa

/// An collection of data records accessed by any filter.
public protocol TableProtocol {
    associatedtype Record: RecordProtocol
    
    /// The number of all records in this table.
    var numberOfRecords: Int { get }
    
    /// Add any new record to the end of table.
    /// - Parameter record: New adding record.
    mutating func add(_ record: Record)
    
    /// Removes the record specified in argument.
    /// If the record specified in arigument does not exsist in this table, removing will be ignoreed.
    /// - Parameter record: Removing reord
    mutating func remove(_ record: Record)
    mutating func remove(_ id: UInt64)
    
    mutating func replace(_ record: Record, to newRecord: Record)
    
    /// Get records filtered by any filter specified in argument.
    /// - Parameter filter: The filter that refine the records to be returned.
    /// - Returns: The record refined by the fileter.
    func getRecords<T>(filteredBy filter: T) -> [Self.Record]
    where T: RecordFilterProtocol, T.RecordType == Self.Record
    
    func getAllRecords() -> [Self.Record]
}
