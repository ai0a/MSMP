public struct UserBan: Codable, Equatable, Sendable {
	public let reason: String
	public let expires: String?
	public let source: String
	public let player: Player

	public init(reason: String, expires: String? = nil, source: String, player: Player) {
		self.reason = reason
		self.expires = expires
		self.source = source
		self.player = player
	}
}