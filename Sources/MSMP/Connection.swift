import Foundation

public actor Connection {
	public init(to host: String, port: UInt16, secret: String) async throws {
		guard let url = URL(string: "ws://\(host):\(port)") else {
			throw Error.badURL
		}
		try await withCheckedThrowingContinuation { connectionContinuation in
			var request = URLRequest(url: url)
			request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
			connection = WebsocketConnection(url: request) { message in
				guard let continuation = await self.continuations[message.id] else {
					print("Got unexpected message \(message)")
					return
				}
				await self.removeContinuation(forId: message.id)
				switch message {
				case let .result(_, result):
					continuation.resume(returning: result)
				case let .error(_, error):
					continuation.resume(throwing: error)
				}
			} connectHandler: {
				connectionContinuation.resume(returning: ())
			} disconnectHandler: { code, data in
				connectionContinuation.resume(throwing: Error.disconnected(code: code, reason: data))
			}
		}
	}

	public enum Error: Swift.Error {
		case badURL
		/// Bad secret?
		case disconnected(code: Int, reason: Data?)
	}

	public func getAllowlist() async throws -> [Player] {
		let response = try await request("minecraft:allowlist")
		return try response.recode(to: [Player].self)
	}

	public func setAllowlist(to players: [Player]) async throws -> [Player] {
		let response = try await request("minecraft:allowlist/set", params: .named(["players": JSONValue(recoding: players)]))
		return try response.recode(to: [Player].self)
	}

	public func addToAllowlist(from players: [Player]) async throws -> [Player] {
		let response = try await request("minecraft:allowlist/add", params: .named(["add": JSONValue(recoding: players)]))
		return try response.recode(to: [Player].self)
	}

	public func addToAllowlist(_ player: Player) async throws -> [Player] {
		try await addToAllowlist(from: [player])
	}

	public func removeFromAllowlist(from players: [Player]) async throws -> [Player] {
		let response = try await request("minecraft:allowlist/remove", params: .named(["remove": JSONValue(recoding: players)]))
		return try response.recode(to: [Player].self)
	}

	public func removeFromAllowlist(_ player: Player) async throws -> [Player] {
		try await removeFromAllowlist(from: [player])
	}

	public func clearAllowlist() async throws -> [Player] {
		let response = try await request("minecraft:allowlist/clear")
		return try response.recode(to: [Player].self)
	}

	public func getBanlist() async throws -> [UserBan] {
		let response = try await request("minecraft:bans")
		return try response.recode(to: [UserBan].self)
	}

	public func setBanlist(to bans: [UserBan]) async throws -> [UserBan] {
		let response = try await request("minecraft:bans/set", params: .named(["bans": JSONValue(recoding: bans)]))
		return try response.recode(to: [UserBan].self)
	}

	public func addToBanlist(from players: [UserBan]) async throws -> [UserBan] {
		let response = try await request("minecraft:bans/add", params: .named(["add": JSONValue(recoding: players)]))
		return try response.recode(to: [UserBan].self)
	}

	public func addToBanlist(_ player: UserBan) async throws -> [UserBan] {
		try await addToBanlist(from: [player])
	}

	public func removeFromBanlist(from players: [Player]) async throws -> [UserBan] {
		let response = try await request("minecraft:bans/remove", params: .named(["remove": JSONValue(recoding: players)]))
		return try response.recode(to: [UserBan].self)
	}

	public func removeFromBanlist(_ player: Player) async throws -> [UserBan] {
		try await removeFromBanlist(from: [player])
	}

	public func clearBanlist() async throws -> [UserBan] {
		let response = try await request("minecraft:bans/clear")
		return try response.recode(to: [UserBan].self)
	}

	public func getIPBanlist() async throws -> [IPBan] {
		let response = try await request("minecraft:ip_bans")
		return try response.recode(to: [IPBan].self)
	}

	public func setIPBanlist(to bans: [IPBan]) async throws -> [IPBan] {
		let response = try await request("minecraft:ip_bans/set", params: .named(["banlist": JSONValue(recoding: bans)]))
		return try response.recode(to: [IPBan].self)
	}

	public func addToIPBanlist(from players: [IncomingIPBan]) async throws -> [IPBan] {
		let response = try await request("minecraft:ip_bans/add", params: .named(["add": JSONValue(recoding: players)]))
		return try response.recode(to: [IPBan].self)
	}

	public func addToIPBanlist(_ player: IncomingIPBan) async throws -> [IPBan] {
		try await addToIPBanlist(from: [player])
	}

	public func removeFromIPBanlist(from players: [String]) async throws -> [IPBan] {
		let response = try await request("minecraft:ip_bans/remove", params: .named(["ip": JSONValue(recoding: players)]))
		return try response.recode(to: [IPBan].self)
	}

	public func removeFromIPBanlist(_ player: String) async throws -> [IPBan] {
		try await removeFromIPBanlist(from: [player])
	}

	public func clearIPBanlist() async throws -> [IPBan] {
		let response = try await request("minecraft:ip_bans/clear")
		return try response.recode(to: [IPBan].self)
	}

	public func getAllConnectedPlayers() async throws -> [Player] {
		let response = try await request("minecraft:players")
		return try response.recode(to: [Player].self)
	}

	// Returns an array of players that GOT KICKED, *NOT* that remain
	public func kickPlayers(_ players: [Kick]) async throws -> [Player] {
		let response = try await request("minecraft:players/kick", params: .named(["kick": JSONValue(recoding: players)]))
		return try response.recode(to: [Player].self)
	}

	public func getOpList() async throws -> [Operator] {
		let response = try await request("minecraft:operators")
		return try response.recode(to: [Operator].self)
	}

	public func setOpList(to bans: [Operator]) async throws -> [Operator] {
		let response = try await request("minecraft:operators/set", params: .named(["operators": JSONValue(recoding: bans)]))
		return try response.recode(to: [Operator].self)
	}

	public func addToOpList(from players: [Operator]) async throws -> [Operator] {
		let response = try await request("minecraft:operators/add", params: .named(["add": JSONValue(recoding: players)]))
		return try response.recode(to: [Operator].self)
	}

	public func addToOpList(_ player: Operator) async throws -> [Operator] {
		try await addToOpList(from: [player])
	}

	public func removeFromOpList(from players: [Player]) async throws -> [Operator] {
		let response = try await request("minecraft:operators/remove", params: .named(["remove": JSONValue(recoding: players)]))
		return try response.recode(to: [Operator].self)
	}

	public func removeFromOpList(_ player: Player) async throws -> [Operator] {
		try await removeFromOpList(from: [player])
	}

	public func clearOpList() async throws -> [Operator] {
		let response = try await request("minecraft:operators/clear")
		return try response.recode(to: [Operator].self)
	}

	public func getStatus() async throws -> ServerState {
		let response = try await request("minecraft:server/status")
		return try response.recode(to: ServerState.self)
	}

	/// Send a `save` request
	/// - Parameter flush: Whether to flush the saved changes
	/// - Returns: Whether the server is saving or not
	public func save(flush: Bool) async throws -> Bool {
		let response = try await request("minecraft:server/save", params: .named(["flush":.boolean(flush)]))
		return try response.recode(to: Bool.self)
	}

	public func send(systemMessage: SystemMessage) async throws -> Bool {
		let response = try await request("minecraft:server/system_message", params: .named(["message":.init(recoding: systemMessage)]))
		return try response.recode(to: Bool.self)
	}

	private var nextID = 0
	private var continuations = [Int:CheckedContinuation<JSONValue, Swift.Error>]()

	private func removeContinuation(forId id: Int) {
		self.continuations.removeValue(forKey: id)
	}

	private func request(_ endpoint: String, params: JSONRPCRequest.Params? = nil) async throws -> JSONValue {
		let id = nextID
		nextID += 1
		return try await withCheckedThrowingContinuation { continuation in
			continuations[id] = continuation
			Task {
				do {
					try await connection.send(JSONRPCRequest(method: endpoint, params: params, id: id))
				} catch let error {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private var connection: WebsocketConnection<JSONRPCRequest, JSONRPCResponse>!
}