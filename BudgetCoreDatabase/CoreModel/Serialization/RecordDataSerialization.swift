//
//  RecordDataSerialization.swift
//  BudgetManager
//
//  Created by Kohei KONISHI on 2020/11/15.
//

import Foundation

open class RecordDataSerialization: NSObject {
    /// Returns a Foundation Object from given recordData.
    open class func recordDataObject(with: Data) throws -> Any {
        return NSNull()
    }
    
    /// Returns RecordData object from a Foundation object.
    open class func data(withRecordDataObject recordDataObject: Any) throws -> Data {
        guard let topContainer = recordDataObject as? NSArray else {
            throw NSError()
        }
        
        let serializer = _RecordDataSerializer()
        let serializedString = try serializer.serialize(container: topContainer)
        
        return serializedString.data(using: .utf8)!
    }
}

// MARK: - RecordDataSerializer

fileprivate struct _RecordDataSerializer {
    enum LineFeedCode: String {
        case unix = "\n"
        case windows = "\r\n"
        case ClassicMac = "\r"
    }
    
    private let keyPrefix: String = "##"
    private let keyValueSeparator = ":"
    private let valueCollectionSeparator = ","
    private let arrayPrefix = "<arr>"
    private let lineFeed: LineFeedCode = .unix
    
    // MARK: - Serialization
    
     func serialize(container: NSArray) throws -> String {
        var str: String = ""

        for _content in container {
            guard let content = _content as? NSDictionary else {
                throw NSError()
            }
            str += try arrayPrefix + serialize(container: content)
        }
        return str
    }
    func serialize(container: NSDictionary) throws -> String {
        var str: String = ""
        for (key, value) in container {
            str += try serialize(forKey: key as! String, object: value as! NSObject)
        }
        return str
    }
        
    func serialize(forKey key: String, object: NSNumber) throws -> String {
        return keyPrefix + key + keyValueSeparator + stringFormat(object) + lineFeed.rawValue
    }
    func serialize(forKey key: String, object: NSString) throws -> String {
        return keyPrefix + key + keyValueSeparator + stringFormat(object) + lineFeed.rawValue
    }
    func serialize(forKey key: String, object: NSArray) throws -> String {
        var str = keyPrefix + key + keyValueSeparator
        
        for value in object {
            if let number = value as? NSNumber {
                str += arrayPrefix + stringFormat(number)
            } else if let string = value as? NSString {
                str += arrayPrefix + stringFormat(string)
            } else {
                throw NSError()
            }
        }
        
        str += lineFeed.rawValue
        return str
    }
    func serialize(forKey key: String, object: NSDictionary) throws -> String {
        var str = keyPrefix + key + lineFeed.rawValue
        
        for (key, value) in object {
            str += try keyPrefix + serialize(forKey: key as! String, object: value as! NSObject)
        }
        
        return str
    }
    
    func serialize(forKey key: String, object: NSObject) throws -> String {
        if object is NSNumber {
            return try serialize(forKey: key, object: object as! NSNumber)
        } else if object is NSString {
            return try serialize(forKey: key, object: object as! NSString)
        } else if object is NSArray {
            return try serialize(forKey: key, object: object as! NSArray)
        } else if object is NSDictionary {
            return try serialize(forKey: key, object: object as! NSDictionary)
        } else {
            throw NSError()
        }
    }

    
    private func stringFormat(_ value: NSNumber) -> String {
        return value.stringValue
    }
    private func stringFormat(_ value: NSString) -> String {
        return "\"\(value as String)\""
    }
}


// MARK: - RecordDataDeserializer

fileprivate struct _RecordDataDeserializer {
    enum LineFeedCode: String {
        case unix = "\n"
        case windows = "\r\n"
        case ClassicMac = "\r"
    }
    
    private let keyPrefix: String = "##"
    private let keyValueSeparator = ":"
    private let valueCollectionSeparator = ","
    private let arrayPrefix = "<arr>"
    private let lineFeed: LineFeedCode = .unix
    
    
    // MARK: - Deserialization
    
    func deserialize(string: String, as type: NSArray.Type) throws -> NSArray {
        for ch in string {
            
        }
        
        return NSArray()
    }
    func deserialize(string: String, as type: NSDictionary) throws -> NSDictionary {
        return NSDictionary()
    }
    private func getKey(string: String) -> String {
        return ""
    }
    private func getValue(string: String, as type: Int.Type) -> Int {
        return 0
    }
}

