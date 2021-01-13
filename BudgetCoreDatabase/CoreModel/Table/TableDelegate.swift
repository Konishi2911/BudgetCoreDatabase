//
//  TableDelegate.swift
//  BudgetCoreDatabase
//
//  Created by Kohei KONISHI on 2020/12/05.
//

import Cocoa

internal enum RecordState {
    case added
    case removed
    case replaced
}

internal protocol TableDelegate {
    /// Tells the delegate when the records in the table is changed.
    ///
    /// `changedItems` has changed records.
    /// For example, when  a record was added to the table, the added record is passed into `changedItems`.
    ///
    /// Especially, in case that a record in the table was replaced, the old record and new record are passed into `changedItems` in that order.
    ///
    /// - Parameters:
    ///   - sender: sender.
    ///   - changedItems: changed Items.
    ///   - state: The status of record changing.
    func contentDidChange<TableType>(sender: TableType, changedItems: [TableType.Record], _ state: RecordState) where TableType: TableProtocol
}
