public struct IPBan: Codable, Equatable, Sendable {
	public let reason: String
	public let expires: String?
	public let source: String
	public let ip: String

	public init(reason: String, expires: String? = nil, source: String, ip: String) {
		self.reason = reason
		self.expires = expires
		self.source = source
		self.ip = ip
	}
}