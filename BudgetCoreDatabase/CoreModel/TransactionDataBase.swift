//
//  TransactionDataBase.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

public struct TransactionDataBase: TableDelegate {
    public static var `default`: Self = .init()
    
    public var table: TransactionsTable
    
    // Singleton
    private init() {
        self.table = TransactionsTable()
        self.table.delegate = self
        
        try? self.loadTable()
    }
    
    private mutating func loadTable() throws {
        let decoder = JSONDecoder()

        let dir = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil, create: false)
        let storingURL = dir.appendingPathComponent("transactionTable.bmt")
        let data = try Data(contentsOf: storingURL)
        
        table = try TransactionsTable( decoder.decode([Transaction].self, from: data))
        table.delegate = self
    }

    // MARK: - Notifications
    
    public static let tableDidUpdate: Notification.Name =
        Notification.Name(rawValue: "BDTableDidUpdate")
    
    func contentDidChange<TableType>(sender: TableType, changedItems: [TableType.Record], _ state: RecordState) where TableType : TableProtocol {
        NotificationCenter.default.post(name: Self.tableDidUpdate, object: self.table)
    }
}
