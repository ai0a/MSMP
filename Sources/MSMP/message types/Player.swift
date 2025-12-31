public struct Player: Codable, Equatable, Sendable {
	public let name: String
	public let id: String?

	public init(name: String, id: String? = nil) {
		self.name = name
		self.id = id
	}
}