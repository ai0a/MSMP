public struct Kick: Codable, Equatable, Sendable {
	public let player: Player
	public let message: Message

	public init(player: Player, message: Message) {
		self.player = player
		self.message = message
	}
}