//
//  RecordDecoder.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/16.
//

import Cocoa

public class RecordDecoder {
    // MARK: - Options
    
    /// The strategy for decoding `Date` values
    public enum DateDecodingStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferedToDate
        
        /// Decode a `Date` as a string parsed by the given formatter
        case formatted(DateFormatter)
    }
    
    /// The strategy to use for non-conforming foating-point values
    public enum NonComformingFloatDecodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case throwing
        
        /// Decode the values from given representation strings
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
    
    /// The strategy to use decoding dates. Default to `.deferedToDate`
    open var dateDecodingStrategy: DateDecodingStrategy = .deferedToDate
    
    
    /// The strategy to use decoding non-conforming numbers. Defalut to `.throwing`
    open var nonConformingFloatDecofingStrategy: NonComformingFloatDecodingStrategy = .throwing
    
    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]
    
    /// Option set on the top level encoder to pass down the decoding hierarchy.
    fileprivate struct _Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let nonconformingFloatDecodingStrategy: NonComformingFloatDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any] = [:]
    }
    
    /// The option set to the top-level decoder.
    fileprivate var options: _Options {
        return _Options(dateDecodingStrategy: dateDecodingStrategy, nonconformingFloatDecodingStrategy: nonConformingFloatDecofingStrategy)
    }
    
    // MARK: - Constructing Record Decoder
    
    /// Initialize `self` with default strategies.
    public init() {}
    
    // MARK: - Decoding Values
    
    /// Decodes a top-level value of the given type from the given Record file.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - returns: A value from the requested type
    /// - throws: `DecodingError.dataCorrupted`if values requested from the payload are corrupted, or if the given data is invalid.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let topLevel: Any
        do {
            topLevel = try RecordDataSerialization.recordDataObject(with: data)
        } catch {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not RecordData Format.", underlyingError: error))
        }
        
        let decoder = _RecordDataDecoder(referencing: topLevel, options: self.options)
        guard let value = try decoder.unbox(topLevel, as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}

// MARK: - _RecordDataDecoder

private class _RecordDataDecoder: Decoder {
    // MARK: - Properties
    
    /// The decoder's strage.
    var storage: _DecodingStorage
    
    /// Options set on the top-level decoder
    var options: RecordDecoder._Options
    
    /// The path to the current point in decoding.
    fileprivate(set) public var codingPath: [CodingKey]
    
    /// Contextual user-provided information for use during decoding.
    var userInfo: [CodingUserInfoKey : Any] {
        self.options.userInfo
    }
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given top-level container and options.
    init(referencing container: Any, at codingPath: [CodingKey] = [], options: RecordDecoder._Options) {
        self.storage = _DecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }
    
    // MARK: - Decoder Methods
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard !(storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }
        
        guard let topContainer = self.storage.topContainer as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "value is not expected type \([String: Any].Type.self)"))
        }
        
        let container = _RecordKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !(self.storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
        }
        
        guard let topContainer = self.storage.topContainer as? [Any] else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "value is not expected type \([String: Any].Type.self)"))
        }
        
        return _RecordUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }
}

// MARK: - Decoding Storage
private struct _DecodingStorage {
    // MARK: - Properties
    
    /// The container stack
    /// Elements may be any one of the RecordData types (NSNull, NSNumber, String, Array, [String : Any]).
    private(set) var containers: [Any] = []
    
    // MARK: - Initialization
    
    /// Initializes `self` with no containers.
    init() {}
    
    // MARK: - Modifying the Stack
    
    var count: Int {
        return self.containers.count
    }
    
    var topContainer: Any {
        precondition(!containers.isEmpty, "Empty container stack.")
        return self.containers.last!
    }
    
    mutating func push(container: __owned Any) {
        self.containers.append(container)
    }
    
    mutating func popContainer() {
        precondition(!containers.isEmpty, "Empty container stack.")
        self.containers.removeLast()
    }
}

// MARK: - Decoding Containers

private struct _RecordKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    
    // MARK: - Properties
    
    /// A reference to the decoder we're reading from.
    private let decoder: _RecordDataDecoder
    
    /// A reference to the container we're reading from.
    private let container: [String: Any]
    
    /// The path of the coding keys taken to get this point in decoding.
    var codingPath: [CodingKey]
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: _RecordDataDecoder, wrapping container: [String: Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }
    
    // MARK: - KeyDecodingContainerProtocol Methods
    
    var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }
    
    func contains(_ key: K) -> Bool {
        return self.container[key.stringValue] != nil
    }
    
    func decodeNil(forKey key: K) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No value associetad key \(key.stringValue)"))
        }
        
        return entry is NSNull
    }
    
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No value associetad key \(key.stringValue)"))
        }
        
        self.decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: String.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Double.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Float.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key)."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: type.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        return value
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Cannot get \(KeyedDecodingContainer<NestedKey>.self) -- no value found for key \(key)")
            )
        }
        
        guard let dictionary = value as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let container = _RecordKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
        return KeyedDecodingContainer(container)
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot get UnkeyedDecodingContainer -- no value found for key \(key)"))
        }
        
        guard let array = value as? [Any] else {
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \([Any].self)"))
        }
        return _RecordUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }
    
    private func _superDecoder(forKey key: __owned CodingKey) throws -> Decoder {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        let value: Any = self.container[key.stringValue] ?? NSNull()
        return _RecordDataDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
    }
    
    func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _RecordKey.super)
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

private struct _RecordUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    // MARK: Properties
    
    /// A reference to the decoder we're reading from.
    var decoder: _RecordDataDecoder
    
    /// A reference to the container we're reading from.
    var container: [Any]
    
    /// The path of coding keys taken to get this point in decoding
    private(set) public var codingPath: [CodingKey]
    
    /// The index of the element we're about to decode.
    private(set) public var currentIndex: Int
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    public init(referencing decoder: _RecordDataDecoder, wrapping container: [Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }

    // MARK: - UnkeyDecodingContainer Methods
    
    var count: Int? {
        return self.container.count
    }
    
    var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }
        
    mutating func decodeNil() throws -> Bool {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        if self.container[self.currentIndex] is NSNull {
            self.currentIndex += 1
            return true
        } else {
            return false
        }
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Bool.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: String.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Double.Type) throws -> Double {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Double.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Float.Type) throws -> Float {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Float.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Int.Type) throws -> Int {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        guard self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: currentIndex)],
                                      debugDescription: "Unleyed container is at end."))
        }
        
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: type.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_RecordKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        self.currentIndex += 1
        return decoded
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }
        
        let value = self.container[currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Cannot get nested keyed container -- found null value instead."))
        }
        
        guard let dictionalry = value as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "value is not expected type \([String: Any].Type.self)"))
        }
        
        self.currentIndex += 1
        let container = _RecordKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionalry)
        return KeyedDecodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(_RecordKey(index: currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }
        
        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Cannot get nested keyed container -- found null value instead."))
        }
        
        guard let array = value as? [Any] else {
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "value is not expected type \([ Any].Type.self)"))
        }
        
        self.currentIndex += 1
        return _RecordUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }
    
    mutating func superDecoder() throws -> Decoder {
        self.decoder.codingPath.append(_RecordKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(codingPath: self.codingPath,
                                      debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }
        
        let value = container[self.currentIndex]
        self.currentIndex += 1
        return _RecordDataDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options)
    }
}

extension _RecordDataDecoder: SingleValueDecodingContainer {
    // MARK: - SingleValueDecodingContainer Methods
    
    private func expectedNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected \(type) but found null value instead."))
        }
    }
    
    func decodeNil() -> Bool {
        return self.storage.topContainer is NSNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Bool.self)!
    }
    
    func decode(_ type: String.Type) throws -> String {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: String.self)!
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Double.self)!
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Float.self)!
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Int.self)!
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Int8.self)!
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Int16.self)!
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Int32.self)!
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Int64.self)!
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: UInt.self)!
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: UInt8.self)!
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: UInt16.self)!
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: UInt32.self)!
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: UInt64.self)!
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        try expectedNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: type.self)!
    }
}

// MARK: - Concrete value Representaions

extension _RecordDataDecoder {
    /// Returns a given value unboxed from the container.
    func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Bool is currently not supported"))
        
        // TODO: Boolean value is currently not supported. More investigation is needed.
    }
    
    func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let int = number.intValue
        guard NSNumber(value: int) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return int
    }
    
    func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let int8 = number.int8Value
        guard NSNumber(value: int8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return int8
    }
    
    func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let int16 = number.int16Value
        guard NSNumber(value: int16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return int16
    }
    
    func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return int32
    }
    
    func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let int64 = number.int64Value
        guard NSNumber(value: int64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return int64
    }
    
    func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let uint = number.uintValue
        guard NSNumber(value: uint) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return uint
    }
    
    func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let uint8 = number.uint8Value
        guard NSNumber(value: uint8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return uint8
    }
    
    func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let uint16 = number.uint16Value
        guard NSNumber(value: uint16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return uint16
    }
    
    func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let uint32 = number.uint32Value
        guard NSNumber(value: uint32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return uint32
    }
    
    func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber,
              number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        let uint64 = number.uint64Value
        guard NSNumber(value: uint64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
        }
        
        return uint64
    }
    
    func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? NSNumber,
           number !== kCFBooleanTrue, number !== kCFBooleanFalse{
            
            let double = number.doubleValue
            guard abs(double) <= Double(Float.greatestFiniteMagnitude) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed number <\(number)> does not fit in \(type)."))
            }
            
            return Float(double)
        } else if let string = value as? String,
                  case .convertFromString(let posInfString, let negInfString, let nanString) = self.options.nonconformingFloatDecodingStrategy {
            if string == posInfString {
                return Float.infinity
            } else if string == negInfString {
                return -Float.infinity
            } else if string == nanString {
                return Float.nan
            }
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
    }
    
    func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? NSNumber,
           number !== kCFBooleanTrue, number !== kCFBooleanFalse {
            
            return number.doubleValue
            
        } else if let string = value as? String,
                  case .convertFromString(let posInfString, let negInfString, let nanString) = self.options.nonconformingFloatDecodingStrategy {
            if string == posInfString {
                return Double.infinity
            } else if string == negInfString {
                return -Double.infinity
            } else if string == nanString {
                return Double.nan
            }
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
    }
    
    func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }
        
        guard let string = value as? String else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "The passed value's type is not expected type \(type)"))
        }
        
        return string
    }
    
    func unbox(_ value: Any, as type: Date.Type) throws -> Date? {
        guard !(value is NSNull) else { return nil }
        
        switch options.dateDecodingStrategy {
        case .deferedToDate:
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try Date(from: self)
            
        case .formatted(let formatter):
            let string = try self.unbox(value, as: String.self)!
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Date string does not match format expected by formatter."))
            }
            
            return date
        }
    }
    
    func unbox(_ value: Any, as type: Decimal.Type) throws -> Decimal? {
        guard !(value is NSNull) else { return nil }
        
        // Attempt to bridge from NSDeciamlNumber.
        if let decimal = value as? Decimal {
            return decimal
        } else {
            let doubleValue = try self.unbox(value, as: Double.self)!
            return Decimal(doubleValue)
        }
    }
    
    func unbox<T: Decodable>(_ value: Any, as type: T.Type) throws -> T? {
        return try unbox_(value, as: type) as? T
    }
    
    func unbox_(_ value: Any, as type: Decodable.Type) throws -> Any? {
        if type == Date.self || type == NSDate.self {
            return try self.unbox(value, as: Date.self)
        } else if type == URL.self || type == NSURL.self {
            guard let urlString = try self.unbox(value, as: String.self) else {
                return nil
            }
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Invalid URL string."))
            }
            return url
        } else if type == Decimal.self || type == NSDecimalNumber.self {
            return try self.unbox(value, as: Decimal.self)
        } else {
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try type.init(from: self)
        }
    }
}

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

fileprivate struct _RecordKey : CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    fileprivate static let `super` = _RecordKey(stringValue: "super")!
}
