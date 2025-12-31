public struct Operator: Codable, Equatable, Sendable {
	public let permissionLevel: Int
	public let bypassesPlayerLimit: Bool
	public let player: Player

	public init(permissionLevel: Int, bypassesPlayerLimit: Bool, player: Player) {
		self.permissionLevel = permissionLevel
		self.bypassesPlayerLimit = bypassesPlayerLimit
		self.player = player
	}
}