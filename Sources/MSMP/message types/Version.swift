public struct Version: Codable, Equatable, Sendable {
	let `protocol`: Int
	let name: String

	public init(`protocol`: Int, name: String) {
		self.`protocol` = `protocol`
		self.name = name
	}
}