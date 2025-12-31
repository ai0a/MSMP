public enum IncomingIPBan: Codable {
	case byIP(IPBan)
	case byUser(UserBan)
	public init(reason: String, expires: String? = nil, source: String, ip: String) {
		self = .byIP(IPBan(reason: reason, source: source, ip: ip))
	}

	public init(reason: String, expires: String? = nil, source: String, player: Player) {
		self = .byUser(UserBan(reason: reason, expires: expires, source: source, player: player))
	}

	public init(from decoder: any Decoder) throws {
		if let result = try? UserBan(from: decoder) {
			self = .byUser(result)
			return
		}
		self = .byIP(try IPBan(from: decoder))
	}
}