public struct SystemMessage: Codable, Equatable, Sendable {
	public let receivingPlayers: [Player]?
	public let isOverlay: Bool
	public let message: Message

	public init(receivingPlayers: [Player]? = nil, isOverlay: Bool, message: Message) {
		self.receivingPlayers = receivingPlayers
		self.isOverlay = isOverlay
		self.message = message
	}

	enum CodingKeys: String, CodingKey {
		case receivingPlayers
		case isOverlay = "overlay"
		case message
	}
}