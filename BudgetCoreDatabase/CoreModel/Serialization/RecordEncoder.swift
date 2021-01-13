//
//  RecordEncoder.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/13.
//

import Cocoa

public class RecordEncoder {
    // MARK: Options
    
    /// The formatting of the output Record data
    public enum DateEncodingStrategy {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferedToDate
                
        /// Encode the `Date` as a string formatted by the given formatter
        case formatted(DateFormatter)
    }
    
    /// The strategy to use for encoding `Float` values.
    public enum NonConformingFloatEncodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case throwing
        
        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
        
    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`
    open var dateEncodingStrategy: DateEncodingStrategy = .deferedToDate
    
    /// The strategy to use in encoding non-conforming numbers. Default to `throwing`
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throwing
    
    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    
    
    /// Options set on the top-level encoder to pass down the encoding hierachy.
    fileprivate struct _Options {
        let dateEncodingStrategy: DateEncodingStrategy
        let nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }
    
    fileprivate var options: _Options {
        return _Options(dateEncodingStrategy: dateEncodingStrategy, nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy, userInfo: userInfo)
    }
    // MARK: - Constructing a Record Encoder
    
    /// Initializes 'self' with default strategies
    public init() {}
    
    // MARK: - encoding Values
    
    /// Encodes the given top-level value ans returns string to export external file.
    ///
    /// - parameter value
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = _RecordEncoder(options: self.options)
        
        guard let topLevel = try encoder.box_(value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }
        
        if topLevel is NSNull {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) encoded as null Record."))
        } else if topLevel is NSNumber {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) encoded as number Record."))
        } else if topLevel is NSString {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) encoded as string Record."))
        }
        
        return try RecordDataSerialization.data(withRecordDataObject: topLevel)
    }
}

// MARK: - _RecordEncoder
fileprivate class _RecordEncoder: Encoder {
    
    /// The path to the current point in encoding
    var codingPath: [CodingKey]
    
    /// The encoder's storage.
    fileprivate var storage: _RecordEncodingStorage
    
    /// Options set on the top-level encoder
    fileprivate let options: RecordEncoder._Options
    
    var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given top-level encoder options
    fileprivate init(options: RecordEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _RecordEncodingStorage()
        self.codingPath = codingPath
    }
    
    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// 'true' if an element has not yet been encoded at this coding path, 'false' otherwise.
    fileprivate var canEncodeNewValue: Bool {
        return self.storage.count == self.codingPath.count
    }
    
    // MARK: - Encoder Methods
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        // If an existing keyed container was already requested, return that one.
        let topContainer: NSMutableDictionary
        if self.canEncodeNewValue {
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }
        
        let container = _RecordKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: NSMutableArray
        if self.canEncodeNewValue {
            // We have not yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            topContainer = container
        }
        
        return _RecordUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}


// MARK: - Encoding Storage and Containers

fileprivate struct _RecordEncodingStorage {
    
    /// The container stack
    /// Elements may be any one of the Record types (NSNull, NSNumber, NSString, NSArray, NSDictionary).
    private(set) fileprivate var containers: [NSObject] = []
    
    // MARK: -Initialization
    
    /// Initializes 'self' with no containers.
    fileprivate init() {}
    
    // MARK: - Modifying the Stack
    
    fileprivate var count: Int {
        return self.containers.count
    }
    
    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }
    
    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }
    
    fileprivate mutating func push(container: NSObject) {
        self.containers.append(container)
    }
    
    fileprivate mutating func popContainer() -> NSObject {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}

fileprivate struct _RecordKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    // MARK: Properties
    
    /// A reference to the encoder we're writing to
    private let encoder: _RecordEncoder
    
    /// A reference to the container we're writing to
    private let container: NSMutableDictionary
    
    /// The path of coding keys taken to get to this point in encoding
    var codingPath: [CodingKey]
    
    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _RecordEncoder, codingPath: [CodingKey], wrapping container: NSMutableDictionary) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }
    
    // MARK: - KeyedEncodingContainerProtocol Methods
    
    mutating func encodeNil(forKey key: K) throws {
        self.container[key.stringValue] = NSNull()
    }
    
    mutating func encode(_ value: Bool, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: String, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
        
    mutating func encode(_ value: Int, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: Int8, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: Int16, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: Int32, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: Int64, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: UInt, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: UInt8, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: UInt16, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: UInt32, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: UInt64, forKey key: K) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    
    mutating func encode(_ value: Double, forKey key: K) throws {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try self.encoder.box(value)
    }
    
    mutating func encode(_ value: Float, forKey key: K) throws {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try self.encoder.box(value)
    }
    
    mutating func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try self.encoder.box(value)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let dictionary = NSMutableDictionary()
        self.container[key.stringValue] = dictionary
        
        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }
        let container = _RecordKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let array = NSMutableArray()
        self.container[key.stringValue] = array
        
        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }
        return _RecordUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }
    
    mutating func superEncoder() -> Encoder {
        return _RecordReferencingEncoder(referencing: self.encoder, key: _RecordKey.super, convertedKey: _RecordKey.super, wrapping: self.container)
    }
    
    mutating func superEncoder(forKey key: K) -> Encoder {
        return _RecordReferencingEncoder(referencing: self.encoder, key: key, convertedKey: key, wrapping: self.container)
    }
    
}

fileprivate struct _RecordUnkeyedEncodingContainer: UnkeyedEncodingContainer {

    /// A reference to the encoder we're writing to.
    private let encoder: _RecordEncoder
    
    /// A reference to the container we're writing to.
    private let container: NSMutableArray
    
    /// The path of coding keys taken to get to this point in encoding.
    private(set) public var codingPath: [CodingKey]
    
    /// The number of elements encoded into the container.
    public var count: Int {
        return self.container.count
    }
    
    // MARK: -Initialization
    
    /// Initilizes 'self' with the given references.
    fileprivate init(referencing encoder: _RecordEncoder, codingPath: [CodingKey], wrapping container: NSMutableArray) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }
    
    mutating func encodeNil() throws {
        self.container.add(NSNull())
    }
    mutating func encode(_ value: Bool) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: String) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: Int) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: Int8) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: Int16) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: Int32) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: Int64) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: UInt) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: UInt8) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: UInt16) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: UInt32) throws {
        self.container.add(self.encoder.box(value))
    }
    mutating func encode(_ value: UInt64) throws {
        self.container.add(self.encoder.box(value))
    }
    
    mutating func encode(_ value: Double) throws {
        self.encoder.codingPath.append(_RecordKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }
        self.container.add(try self.encoder.box(value))
    }
    
    mutating func encode(_ value: Float) throws {
        self.encoder.codingPath.append(_RecordKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }
        self.container.add(try self.encoder.box(value))
    }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        self.encoder.codingPath.append(_RecordKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }
        self.container.add(try self.encoder.box(value))
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        self.codingPath.append(_RecordKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)
        
        let container = _RecordKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.codingPath.append(_RecordKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }

        let array = NSMutableArray()
        self.container.add(array)
        
        return _RecordUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }
    
    mutating func superEncoder() -> Encoder {
        return _RecordReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
    }
}

extension _RecordEncoder: SingleValueEncodingContainer {
    
    // MARK: - SingleValueEncodingContainer Methods
    
    fileprivate func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
    }
    
    func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(container: NSNull())
    }
    
    func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        try self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        try self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        assertCanEncodeNewValue()
        try self.storage.push(container: self.box(value))
    }
}

// MARK: - Concrete Value Representations
extension _RecordEncoder {
    fileprivate func box(_ value: Bool)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int)    -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int8)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int16)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int32)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int64)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt8)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt16) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt32) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt64) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: String) -> NSObject { return NSString(string: value) }
    
    fileprivate func box(_ float: Float) throws -> NSObject {
        guard !float.isInfinite && !float.isNaN else {
            guard case let .convertToString(positiveInfinity: posInfString,
                                   negativeInfinity: negInfString,
                                   nan: nanString) = self.options.nonConformingFloatEncodingStrategy else {
                throw EncodingError._invalidFloatingPointValue(float, at: codingPath)
            }
            
            if float == Float.infinity {
                return NSString(string: posInfString)
            } else if float == -Float.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }
        return NSNumber(value: float)
    }
    
    fileprivate func box(_ float: Double) throws -> NSObject {
        guard !float.isInfinite && !float.isNaN else {
            guard case let .convertToString(positiveInfinity: posInfString,
                                   negativeInfinity: negInfString,
                                   nan: nanString) = self.options.nonConformingFloatEncodingStrategy else {
                throw EncodingError._invalidFloatingPointValue(float, at: codingPath)
            }
            
            if float == Double.infinity {
                return NSString(string: posInfString)
            } else if float == -Double.infinity {
                return NSString(string: negInfString)
            } else {
                return NSString(string: nanString)
            }
        }
        return NSNumber(value: float)
    }
    
    fileprivate func box(_ date: Date) throws -> NSObject {
        switch self.options.dateEncodingStrategy {
        case .deferedToDate:
            try date.encode(to: self)
            return self.storage.popContainer()
        case .formatted(let formatter):
            return NSString(string: formatter.string(from: date))
        }
    }
    
    fileprivate func box<T: Encodable>(_ value: T) throws -> NSObject {
        return try self.box_(value) ?? NSDictionary()
    }
    fileprivate func box_<T: Encodable>(_ value: T) throws -> NSObject? {
        if T.self == Date.self || T.self == NSDate.self {
            // Respect Date encoding strategy
            return try self.box((value as! Date))
        } else if T.self == Decimal.self || T.self == NSDecimalNumber.self {
            // JSONSerialization can natively handle NSDecimalNumber.
            return (value as! NSDecimalNumber)
        }
        
        // The value should request a container from the _RecordEncoder
        let depth = self.storage.count
        try value.encode(to: self)
        
        // The top container should be a new container
        guard self.storage.count > depth else {
            return nil
        }
        
        return self.storage.popContainer()
    }
}

//MARK: - _RecordReferenceinhEncoder

fileprivate class _RecordReferencingEncoder: _RecordEncoder {
    
    /// The type of container we're referencing.
    private enum Reference {
        /// Referenceing a specific index in an array container.
        case array(NSMutableArray, Int)
        
        /// Referencing a specific key in a dictionary container.
        case dictionary(NSMutableDictionary, String)
    }
    
    // MARK: - Properties
    
    /// The encoder we're referencing.
    fileprivate let encoder: _RecordEncoder
    
    /// The container reference itself.
    private let reference: Reference
    
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given array container in the given encoder.
    fileprivate init(referencing encoder: _RecordEncoder, at index: Int, wrapping array: NSMutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(_RecordKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(referencing encoder: _RecordEncoder,
                     key: CodingKey, convertedKey: CodingKey, wrapping dictionary: NSMutableDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, convertedKey.stringValue)
        super.init(options: encoder.options, codingPath: encoder.codingPath)

        self.codingPath.append(key)
    }
    
    // MARK: - Code Path Operation
    
    fileprivate override var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }
    
    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's  storage.
    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on    stack.")
        }
    
        switch self.reference {
        case .array(let array, let index):
            array.insert(value, at: index)
    
        case .dictionary(let dictionary, let key):
            dictionary[NSString(string: key)] = value
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
//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

fileprivate extension EncodingError {
    /// Returns a `.invalidValue` error describing the given invalid floating-point value.
    ///
    ///
    /// - parameter value: The value that was invalid to encode.
    /// - parameter path: The path of `CodingKey`s taken to encode this value.
    /// - returns: An `EncodingError` with the appropriate path and debug description.
    static func _invalidFloatingPointValue<T : FloatingPoint>(_ value: T, at codingPath: [CodingKey]) -> EncodingError {
        let valueDescription: String
        if value == T.infinity {
            valueDescription = "\(T.self).infinity"
        } else if value == -T.infinity {
            valueDescription = "-\(T.self).infinity"
        } else {
            valueDescription = "\(T.self).nan"
        }

        let debugDescription = "Unable to encode \(valueDescription) directly in JSON. Use JSONEncoder.NonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded."
        return .invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: debugDescription))
    }
}
