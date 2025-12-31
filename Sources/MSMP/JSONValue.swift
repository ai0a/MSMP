import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let boolean = try? container.decode(Bool.self) {
            self = .boolean(boolean)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public func recode<T: Decodable>(to: T.Type) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: try encoder.encode(self))
    }

    public init<T: Encodable>(recoding other: T) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: try encoder.encode(other))
    }
}

extension JSONValue: CustomStringConvertible {
    public var description: String {
        let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		return String(decoding: try! encoder.encode(self), as: UTF8.self)
    }
}