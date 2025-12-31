public struct Version: Codable, Equatable, Sendable {
	public let `protocol`: Int
	public let name: String

	public init(`protocol`: Int, name: String) {
		self.`protocol` = `protocol`
		self.name = name
	}
}