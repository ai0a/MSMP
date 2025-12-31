public struct Message: Codable, Equatable, Sendable {
	public let translatable: String?
	public let translatableParams: [String]?
	public let literal: String?

	public init(translatable: String? = nil, translatableParams: [String]? = nil, literal: String? = nil) {
		self.translatable = translatable
		self.translatableParams = translatableParams
		self.literal = literal
	}
}

extension Message: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
		self.init(literal: value)
	}
}