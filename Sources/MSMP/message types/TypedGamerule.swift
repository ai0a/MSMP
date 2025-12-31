public struct TypedGamerule: Codable, Equatable, Sendable {
	public let key: String
	public let value: Value

	public enum Value: Equatable, Sendable {
		case integer(Int)
		case boolean(Bool)
	}

	public init(key: String, value: TypedGamerule.Value) {
		self.key = key
		self.value = value
	}

	private enum CodingKeys: CodingKey {
		case type
		case value
		case key
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		key = try container.decode(String.self, forKey: .key)
		switch try container.decode(String.self, forKey: .type) {
		case "integer":
			value = .integer(Int(try container.decode(String.self, forKey: .value)) ?? 0)
		case "boolean":
			value = .boolean(Bool(try container.decode(String.self, forKey: .value)) ?? false)
		default:
			throw Error.unknownType(try container.decode(String.self, forKey: .type))
		}
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(key, forKey: .key)
		switch value {
		case let .integer(value):
			try container.encode(value, forKey: .value)
			try container.encode("integer", forKey: .type)
		case let .boolean(value):
			try container.encode(value, forKey: .value)
			try container.encode("boolean", forKey: .type)
		}
	}

	public enum Error: Swift.Error {
		case unknownType(String)
	}
}