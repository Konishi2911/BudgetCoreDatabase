//
//  TransactionTable.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/09.
//

import Cocoa

/// Table that store ans manage transactions.
public struct TransactionsTable: TableProtocol, RecordSortable, Decodable {
    public typealias Record = Transaction
    
    /// The delegate to tell that the records are changed.
    internal var delegate: TableDelegate?
    
    // MARK: - Options
    
    public enum StoringTiming {
        case storeDidCall
        case recordDicChange
    }
    
    public enum SortingTiming {
        case sortDidCall
        case whenSortIsRequired
    }
    
    public enum FileFormat {
        case json
    }
    
    public var storeTiming: StoringTiming = .storeDidCall
    public var sortTiming: SortingTiming = .sortDidCall
    public var fileFormat: FileFormat = .json
    
    
    // MARK: Private Properties
    
    private var _didSort: Bool = false {
        didSet {
            if !_didSort && self.sortTiming == .whenSortIsRequired {
                self.sort()
            }
        }
    }
    private var __rec: [Transaction] = []
    private var _records: [Transaction] {
        get { self.__rec }
        set(v) {
            __rec = v
            
            // Set flag that this table is not sorted.
            self._didSort = false;
            
            // Store this table to external file if store timing is `recordDidChange`.
            if storeTiming == .recordDicChange {
                do {
                    try self.store()
                } catch {
                    fatalError("Unable to store the Record.")
                }
            }
        }
    }
    private var _idCounter: UInt64 = 0
    
    
    // MARK: - Initilization
    
    /// Initilizes `self` with default options.
    public init() {
        // Empty Items
        _records = [];
    }
    
    /// Initilizes `self` with initial records and with default options.
    /// - Parameters:
    ///   - transactions: Initial records
    public init(_ transactions: [Transaction]) {
        for item in transactions {
            self.add(item)
        }
    }
    
    public init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        let records = try values.decode([Transaction].self)
        
        self.init(records)
    }
    
    internal init(delegate: TableDelegate) {
        // Empty Items
        _records = [];
        self.delegate = delegate
    }
    
    public var numberOfRecords: Int {
        return _records.count
    }
    
    // MARK: - Table Operating Methods
    
    public mutating func add(_ record: Transaction) {
        let addingTransction = Transaction(_idCounter, record: record)
        _records.append(addingTransction)
        _idCounter += 1
        
        self.delegate?.contentDidChange(sender: self,
                                        changedItems: [addingTransction],
                                        .added)
    }
    public mutating func remove(_ record: Transaction) {
        guard record.id != nil else { return }
        
        if let index = _records.firstIndex(of: record) {
            let removedItem = self._records.remove(at: index)
            
            self.delegate?.contentDidChange(sender: self,
                                            changedItems: [removedItem],
                                            .removed)
        }
    }
    public mutating func remove(_ id: UInt64) {
        var index = 0
        for record in _records {
            if record.id == id {
                let removedItem = _records.remove(at: index)
                
                self.delegate?.contentDidChange(sender: self,
                                                changedItems: [removedItem],
                                                .removed)
            }
            index += 1
        }
    }
    
    mutating public func replace(_ record: Transaction, to newRecord: Transaction) {
        guard let id = record.id else { return }
        
        // Removing the old Record
        if let index = _records.firstIndex(of: record) {
            self._records.remove(at: index)
        }
        
        // Adding the new Record
        self._records.append(Transaction(id, record: newRecord))
        
        // Post record replaced event
        self.delegate?.contentDidChange(sender: self,
                                        changedItems: [record, newRecord],
                                        .replaced)
    }

    
    public func getRecords<T>(filteredBy filter: T) -> [Transaction] where T : RecordFilterProtocol, Self.Record == T.RecordType {
        return filter.filter(_records)
    }
    public func getAllRecords() -> [Transaction] {
        return _records
    }
    
    // MARK: - sorting Records
    
    public mutating func sort() {
        let sorter = BubbleSorter(direction: .ascending)
        
        let sortedRecords = sorter.sort(items: _records) {
            (transaction: Transaction) in
            transaction.date
        }
        
        __rec = sortedRecords
        self._didSort = true
    }
    
    // MARK: - storing Records
    
    /// Stores the records to external file.
    public func store() throws {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil, create: false)
        try self.store(to: dir)
    }
    public func store(to directory: URL) throws {
        let serializedData: Data
        switch fileFormat {
        case .json:
            let encoder = JSONEncoder()
            
            serializedData = try encoder.encode(_records)
        }
        
        let storingURL = directory.appendingPathComponent("transactionTable.bmt")
        print("Storing URL: \(storingURL)")

        try serializedData.write(to: storingURL, options: .atomic)
    }
}

// MASK: - FileWritingError

fileprivate enum FileWritingError: Error {
    case permissionDenied
}
