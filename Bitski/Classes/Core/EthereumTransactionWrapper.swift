import Foundation
import OrderedCollections
import Web3

public struct EthereumTransactionWrapper: Codable {
    public var nonce: EthereumQuantity? = nil
    public var gasPrice: EthereumQuantity?  = nil
    public var maxFeePerGas: EthereumQuantity? = nil
    public var maxPriorityFeePerGas: EthereumQuantity? = nil
    public var gasLimit: EthereumQuantity? = nil
    public var gas: EthereumQuantity? = nil
    public var from: EthereumAddress? = nil
    public var to: EthereumAddress? = nil
    public var value: EthereumQuantity? = nil
    public var data: EthereumData
    public var accessList: OrderedDictionary<EthereumAddress, [EthereumData]>
    public var transactionType: EthereumTransaction.TransactionType
    public var type: EthereumQuantity = EthereumQuantity(quantity: 0)

    public init() {
        self.data = EthereumData.init([])
        self.accessList = OrderedDictionary<EthereumAddress, [EthereumData]>()
        self.transactionType = EthereumTransaction.TransactionType.legacy
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: EthereumTransactionWrapper.CodingKeys.self)
        self.nonce = try? container.decode(EthereumQuantity.self, forKey: .nonce)
        self.gasPrice = try? container.decode(EthereumQuantity.self, forKey: .gasPrice)
        self.maxFeePerGas = try? container.decode(EthereumQuantity.self, forKey: .maxFeePerGas)
        self.maxPriorityFeePerGas = try? container.decode(EthereumQuantity.self, forKey: .maxPriorityFeePerGas)
        self.gas = try? container.decode(EthereumQuantity.self, forKey: .gas)
        self.gasLimit = (try? container.decode(EthereumQuantity.self, forKey: .gasLimit)) ?? self.gas
        self.from = try? container.decode(EthereumAddress.self, forKey: .from)
        self.to = try? container.decode(EthereumAddress.self, forKey: .to)
        self.value = (try? container.decode(EthereumQuantity.self, forKey: .value))
            ?? .init(quantity: 0)
        self.data = try container.decode(EthereumData.self, forKey: .data)
        self.accessList = (try? container.decode(OrderedDictionary.self, forKey: .accessList))
            ?? OrderedDictionary<EthereumAddress, [EthereumData]>()
        
        if let txnType = try? container.decode(EthereumTransaction.TransactionType.self, forKey: .transactionType) {
            self.transactionType = txnType
        } else {
            self.transactionType = .legacy
        }
        
        if (self.maxFeePerGas != nil) {
            self.transactionType = .eip1559
        }
        
        if let type = try? container.decode(EthereumQuantity.self, forKey: .type) {
            self.type = type
        } else {
            self.type = self.transactionType == .legacy ? EthereumQuantity(quantity: 1) : EthereumQuantity(quantity: 2)
        }
    }
    
    public var unwrap: EthereumTransaction {
        EthereumTransaction(
            nonce: self.nonce,
            gasPrice: self.gasPrice,
            maxFeePerGas: self.maxFeePerGas,
            maxPriorityFeePerGas: self.maxPriorityFeePerGas,
            gasLimit: self.gasLimit ?? self.gas,
            from: self.from,
            to: self.to,
            value: self.value,
            data: self.data,
            accessList: self.accessList,
            transactionType: self.transactionType
        )
    }
    
    enum CodingKeys: CodingKey {
        case nonce
        case gasPrice
        case maxFeePerGas
        case maxPriorityFeePerGas
        case gasLimit
        case gas
        case from
        case to
        case value
        case data
        case accessList
        case transactionType
        case type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let nonce = self.nonce {
            try container.encodeIfPresent(nonce, forKey: .nonce)
        } else {
            try container.encodeNil(forKey: .nonce)
        }
        
        if let gasPrice = self.gasPrice {
            try container.encode(gasPrice, forKey: .gasPrice)
        } else {
            try container.encodeNil(forKey: .gasPrice)
        }
        
        if let maxFeePerGas = self.maxFeePerGas {
            try container.encode(maxFeePerGas, forKey: .maxFeePerGas)
        } else {
            try container.encodeNil(forKey: .maxFeePerGas)
        }
        
        if let maxPriorityFeePerGas = self.maxPriorityFeePerGas {
            try container.encode(maxPriorityFeePerGas, forKey: .maxPriorityFeePerGas)
        } else {
            try container.encodeNil(forKey: .maxPriorityFeePerGas)
        }
        
        // Don't encode a gas field, always encode using gasLimit
        if let gasLimit = self.gasLimit ?? self.gas {
            try container.encode(gasLimit, forKey: .gasLimit)
        } else {
            try container.encodeNil(forKey: .gasLimit)
        }
        
        if let from = self.from {
            try container.encode(from, forKey: .from)
        } else {
            try container.encodeNil(forKey: .from)
        }
        
        if let to = self.to {
            try container.encode(to, forKey: .to)
        } else {
            try container.encodeNil(forKey: .to)
        }
        
        // Encode value as zero if missing, never as null.
        let value = self.value ?? EthereumQuantity(quantity: 0)
        try container.encode(value, forKey: .value)
         
        // Non-optional fields
        try container.encode(self.data, forKey: .data)
        try container.encode(self.accessList, forKey: .accessList)
        // try container.encode(self.transactionType, forKey: .transactionType)
        try container.encode(self.type, forKey: .type)
    }
}

extension EthereumTransaction {
    public var wrap: EthereumTransactionWrapper {
        var result = EthereumTransactionWrapper()
        result.nonce = self.nonce
        result.gasPrice = self.gasPrice
        result.maxFeePerGas = self.maxFeePerGas
        result.maxPriorityFeePerGas = self.maxPriorityFeePerGas
        result.gasLimit = self.gasLimit
        result.gas = self.gasLimit
        result.from = self.from
        result.to = self.to
        result.value = self.value
        result.data = self.data
        result.accessList = self.accessList
        result.transactionType = self.transactionType
        result.type = self.maxFeePerGas == nil ? .init(quantity: 1) : .init(quantity: 2)
        return result
    }
}
