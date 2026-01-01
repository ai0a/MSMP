struct JSONRPCRequest: Codable {
	let method: String
	let params: Params?
	// Could technically be a string or other number, but not for msmp in practice
	let id: Int?

	enum Params: Codable {
		case named([String: JSONValue])
		case list([JSONValue])

		public subscript(_ name: String, orPositional position: Int) -> JSONValue? {
			switch self {
			case let .named(dict):
				return dict[name]
			case let .list(list):
				guard list.count > position else {
					return nil
				}
				return list[position]
			}
		}

		public init(from decoder: any Decoder) throws {
			if var container = try? decoder.unkeyedContainer() {
				var result = [JSONValue]()
				while !container.isAtEnd {
					result.append(try container.decode(JSONValue.self))
				}
				self = .list(result)
				return
			}
			self = .named(try decoder.singleValueContainer().decode([String:JSONValue].self))
		}

		public func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()
			switch self {
			case let .named(value):
				try container.encode(value)
			case let .list(value):
				try container.encode(value)
			}
		}
	}
}