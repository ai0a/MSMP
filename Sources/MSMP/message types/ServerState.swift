public struct ServerState: Codable, Equatable, Sendable {
	public let players: [Player]?
	public let isStarted: Bool
	public let version: Version

	public init(players: [Player]? = nil, isStarted: Bool, version: Version) {
		self.players = players
		self.isStarted = isStarted
		self.version = version
	}

	enum CodingKeys: String, CodingKey {
		case players
		case isStarted = "started"
		case version
	}
}