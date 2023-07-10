import Web3
import Foundation
import OrderedCollections

public enum AnyEthereumTypeDictioanryValue: Codable {
    case value(EthereumValue)
    case dictionary([String: Self])
    case array([Self])
    case null
    
    static func fromDictionary(ethereumObject param: [String: Any]) -> [String: Self] {
        let dictionary:  [String: Self] = param.compactMapValues { param in
            if let param = param as? [String: Any] {
                let dictionary =  Self.fromDictionary(ethereumObject: param)
                return Self.dictionary(dictionary)
            } else if let value = AnyEthereumType.ethereumValue(from: param) {
                return Self.value(value)
            } else {
                return nil
            }
        }
        return dictionary
    }
    
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let value):
            try container.encode(value)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(EthereumValue.self) {
            self = .value(value)
            return
        }
        
        if let dictionary = try? container.decode([String: Self].self) {
            self = .dictionary(dictionary)
            return
        }
        
        if let array = try? container.decode([Self].self) {
            self = .array(array)
            return
        }

        if container.decodeNil() {
            self = .null
            return
        }
        
        throw DecodingError.typeMismatch(AnyEthereumType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ResponseType"))
    }
    
    public var value: EthereumValue? {
        get {
            switch self {
            case .value(let value):
                return value
            default:
                return nil
            }
        }
    }
}

public enum AnyEthereumType: Codable {
    case value(EthereumValue)
    case block(EthereumBlockObject)
    case transactionObject(EthereumTransactionObject)
    case transaction(EthereumTransactionWrapper)
    case array([Self])
    case dictionary([String: AnyEthereumTypeDictioanryValue])
    case null

    public var transaction: EthereumTransactionWrapper? {
        get {
            switch self {
            case .transaction(let transaction):
                return transaction
            case .array(let array):
                if case .transaction(let txn) = array.first {
                    return txn
                } else {
                    return nil
                }
            case .dictionary(let dict):
                return EthereumTransactionWrapper(param: dict)
            default:
                return nil
            }
        }
    }
    
    public var value: EthereumValue? {
        get {
            switch self {
            case .value(let value):
                return value
            default:
                return nil
            }
        }
    }
    
    var array: [Self]? {
        get {
            switch self {
            case .array(let array):
                return array
            default:
                return nil
            }
        }
    }
    
    public var dictionary: [String: AnyEthereumTypeDictioanryValue]? {
        get {
            switch self {
            case .dictionary(let dictionary):
                return dictionary
            default:
                return nil
            }
        }
    }

    
    public var stringOrJSON: String? {
        get {
            switch self {
            case .value(let value):
                return value.string
            default:
                let data = try? JSONEncoder().encode(self)
                let string = String(data: data ?? Data(), encoding: .utf8)
                return string
            }
        }

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let transactionObject = try? container.decode(EthereumTransactionObject.self) {
            self = .transactionObject(transactionObject)
            return
        }
        if let transaction = try? container.decode(EthereumTransactionWrapper.self) {
            self = .transaction(transaction)
            return
        }

        if let block = try? container.decode(EthereumBlockObject.self) {
            self = .block(block)
            return
        }
        if let value = try? container.decode(EthereumValue.self) {
            self = .value(value)
            return
        }
        if let dictionary = try? container.decode([String: AnyEthereumTypeDictioanryValue].self) {
            self = .dictionary(dictionary)
            return
        }
        if let array = try? container.decode([Self].self) {
            self = .array(array)
            return
        }
        
        if container.decodeNil() {
            self = .null
            return
        }

        throw DecodingError.typeMismatch(AnyEthereumType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ResponseType"))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .transaction(let transaction):
            try container.encode(transaction)
        case .transactionObject(let transactionObject):
            try container.encode(transactionObject)
        case .block(let block):
            try container.encode(block)
        case .value(let value):
            try container.encode(value)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .null:
            try container.encodeNil()
        }
    }
    
    public static func fromDictionary(ethereumObject param: [String: Any], dictionaryOnly: Bool) -> Self? {
        if dictionaryOnly {
            let dictionary = AnyEthereumTypeDictioanryValue.fromDictionary(ethereumObject: param)
            
            return .dictionary(dictionary)
        }
        if let txn = EthereumTransactionWrapper(param: param) {
            return .transaction(txn)
        }

        var convertedParams: [String: Encodable] = param.compactMapValues({ value in
            if let value = value as? Encodable {
                return value
            }
            
            if let value = value as? String {
                return value as Encodable
            }
            
            return nil
        })
        
        if convertedParams.isEmpty {
            return nil
        }
        
        // Hack because web3.swift's transactions require a data field
        if convertedParams["data"] == nil {
            convertedParams["data"] = "0x"
        }
        
        do {
            let jsonData = try JSONEncoder().encode(convertedParams)
            return try JSONDecoder().decode(Self.self, from: jsonData)
        } catch {
            return nil
        }
    }
    
    public static func ethereumValue(from value: Any) -> EthereumValue? {
        if let self = value as? Self {
            return self.value
        }
        
        if let value = value as? [Self] {
            let values = value.compactMap({$0.value})
            return EthereumValue(array: values)
        }
        
        if let value = value as? Encodable, let data = try? JSONEncoder().encode(value), let decoded = try? JSONDecoder().decode(EthereumValue.self, from: data) {
            return decoded
        }
        
        if let value = value as? String, let data = try? JSONEncoder().encode(value), let decoded = try? JSONDecoder().decode(EthereumValue.self, from: data) {
            return decoded
        }
        
        return nil
    }

}

extension JSONEncoder {
    private struct EncodableWrapper: Encodable {
        let wrapped: Encodable

        func encode(to encoder: Encoder) throws {
            try self.wrapped.encode(to: encoder)
        }
    }
    func encode<Key: Encodable>(_ dictionary: [Key: Encodable]) throws -> Data {
        let wrappedDict = dictionary.mapValues(EncodableWrapper.init(wrapped:))
        return try self.encode(wrappedDict)
    }
}

extension EthereumTransactionWrapper {
    init?(param: [String: Any]) {
        var convertedParams: [String: Decodable] = param.compactMapValues({ value in
            if let value = value as? Decodable {
                return value
            }
            
            if let value = value as? String {
                return value as Decodable
            }
            
            return nil
        })
        
        if convertedParams.isEmpty {
            return nil
        }
        
        // Hack because web3.swift's transactions require a data field
        if convertedParams["data"] == nil {
            convertedParams["data"] = "0x"
        }
        
        var result = EthereumTransactionWrapper()
        
        // optional
        if case .value(let g) = (convertedParams["gas"] as? AnyEthereumType),
           let gasLimit = try? EthereumQuantity(ethereumValue: g) {
            result.gasLimit = gasLimit
            result.transactionType = .legacy
        }
        // optional
        else if case .value(let g) = (convertedParams["gasLimit"] as? AnyEthereumType),
                  let gasLimit = try? EthereumQuantity(ethereumValue: g) {
            result.gasLimit = gasLimit
            result.transactionType = .eip1559
        }
        
        if case .value(let g) = (convertedParams["gasPrice"] as? AnyEthereumType),
                  let gasPrice = try? EthereumQuantity(ethereumValue: g) {
            result.gasPrice = gasPrice
            result.transactionType = .legacy
        }
        
        if let t = convertedParams["transactionType"] as? String {
            result.transactionType = EthereumTransaction.TransactionType(rawValue: t) ?? result.transactionType
        }
        
        if case .value(let n) = (convertedParams["nonce"] as? AnyEthereumType),
           let nonce = try? EthereumQuantity(ethereumValue: n) {
            result.nonce = nonce
        }
        
        // optional
        if let v = convertedParams["value"] as? String, let value = try? EthereumQuantity(ethereumValue: v) {
            result.value = value
        }
        
        // optional
        if case .value(let t) = (convertedParams["to"] as? AnyEthereumType),
           let to = try? EthereumAddress(ethereumValue: t) {
            result.to = to
        } else if let to = convertedParams["to"] as? String, let address = try? EthereumAddress(hex: to, eip55: false) {
            result.to = address
        }
        
        // @Patrick, how do you recommend ethereum data and from get parsed?
        if let dataString = convertedParams["data"] as? String,
           let data = try? EthereumData(ethereumValue: .string(dataString)) {
            result.data = data
        } else if let dataString = convertedParams["data"] as? String,
                  let stringData = Data(hexString: dataString),
                  let data: EthereumData = try? JSONDecoder().decode(EthereumData.self, from: stringData) {
            result.data = data
        }
        
        // required
        guard let fromString = convertedParams["from"] as? String,
              let from = EthereumAddress(hexString: fromString)
        else {
            return nil
        }
        
        result.from = from
        self = result
    }
}
