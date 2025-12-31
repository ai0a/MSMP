enum JSONRPCResponse: Codable {
	case result(id: Int, JSONValue)
	case error(id: Int, JSONRPCError)

	public var id: Int {
		switch self {
		case let .result(id, _): id
		case let .error(id, _): id
		}
	}

	private enum CodingKeys: CodingKey {
		case id
		case result
		case error
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let id = try container.decode(Int.self, forKey: .id)
		if let error = try? container.decode(JSONRPCError.self, forKey: .error) {
			self = .error(id: id, error)
			return
		}
		self = .result(id: id, try container.decode(JSONValue.self, forKey: .result))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		switch self {
		case let .error(id: _, error):
			try container.encode(error, forKey: .error)
		case let .result(id: _, result):
			try container.encode(result, forKey: .result)
		}
	}
}