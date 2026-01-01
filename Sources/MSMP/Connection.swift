import Foundation

private actor Isolated<T> {
	var value: T
	init(_ value: T) {
		self.value = value
	}

	func set(to value: T) {
		self.value = value
	}
}

public actor Connection {
	private var url: URL
	private var secret: String
	
	public init(to host: String, port: UInt16, secret: String) async throws {
		guard let url = URL(string: "ws://\(host):\(port)") else {
			throw Error.badURL
		}
		self.url = url
		self.secret = secret
		try await withCheckedThrowingContinuation { connectionContinuation in
			var request = URLRequest(url: url)
			request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
			let hasResumed = Isolated(false)
			connection = WebsocketConnection(url: request) { message in
				try await self.handleIncomingMessage(message)
			} connectHandler: {
				if await hasResumed.value {
					return
				}
				await hasResumed.set(to: true)
				connectionContinuation.resume(returning: ())
			} disconnectHandler: { code, data in
				await self.handleDisconnection(code, reason: data)
				if await hasResumed.value {
					return
				}
				await hasResumed.set(to: true)
				connectionContinuation.resume(throwing: Error.disconnected(code: code, reason: data))
			}
		}
	}

	public enum Error: Swift.Error {
		case badURL
		/// Bad secret?
		case disconnected(code: Int, reason: Data?)
		case alreadyWaitingForNotification
		case alreadyConnected
	}

	public var nextNotification: Notification {
		get async throws {
			guard await connection.isActive else {
				throw Error.disconnected(code: await connection.closeCode, reason: nil)
			}
			guard notificationQueue.isEmpty else {
				let result = notificationQueue[0]
				notificationQueue.removeFirst()
				return result
			}
			
			try await withCheckedThrowingContinuation { continuation in
				Task {
					do {
						try setNextNotificationContinuation(to: continuation)
					} catch let error {
						continuation.resume(throwing: error)
					}
				}
			}
			nextNotificationContinuation = nil
			let result = notificationQueue[0]
			notificationQueue.removeFirst()
			return result
		}
	}

	public var isConnected: Bool {
		get async {
			await connection.isActive
		}
	}

	public func reconnect() async throws {
		guard await !isConnected else {
			throw Error.alreadyConnected
		}
		try await withCheckedThrowingContinuation { connectionContinuation in
			var request = URLRequest(url: url)
			request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
			let hasResumed = Isolated(false)
			connection = WebsocketConnection(url: request) { message in
				try await self.handleIncomingMessage(message)
			} connectHandler: {
				if await hasResumed.value {
					return
				}
				await hasResumed.set(to: true)
				connectionContinuation.resume(returning: ())
			} disconnectHandler: { code, data in
				await self.handleDisconnection(code, reason: data)
				if await hasResumed.value {
					return
				}
				await hasResumed.set(to: true)
				connectionContinuation.resume(throwing: Error.disconnected(code: code, reason: data))
			}
		}
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

	public func stop() async throws -> Bool {
		let response = try await request("minecraft:server/stop")
		return try response.recode(to: Bool.self)
	}

	public func send(systemMessage: SystemMessage) async throws -> Bool {
		let response = try await request("minecraft:server/system_message", params: .named(["message":.init(recoding: systemMessage)]))
		return try response.recode(to: Bool.self)
	}

	public func getAutosaveIsEnabled() async throws -> Bool {
		let response = try await request("minecraft:serversettings/autosave")
		return try response.recode(to: Bool.self)
	}

	public func setAutosaveIsEnabled(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/autosave/set", params: .named(["enable": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getDifficulty() async throws -> Difficulty {
		let response = try await request("minecraft:serversettings/difficulty")
		return Difficulty(rawValue: try response.recode(to: String.self)) ?? .peaceful
	}

	public func setDifficulty(to value: Difficulty) async throws -> Difficulty {
		let response = try await request("minecraft:serversettings/difficulty/set", params: .named(["difficulty": JSONValue(recoding: value.rawValue)]))
		return Difficulty(rawValue: try response.recode(to: String.self)) ?? .peaceful
	}

	public func getAllowlistIsEnforced() async throws -> Bool {
		let response = try await request("minecraft:serversettings/enforce_allowlist")
		return try response.recode(to: Bool.self)
	}

	public func setAllowlistIsEnforced(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/enforce_allowlist/set", params: .named(["enforce": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getAllowlistIsUsed() async throws -> Bool {
		let response = try await request("minecraft:serversettings/use_allowlist")
		return try response.recode(to: Bool.self)
	}

	public func setAllowlistIsUsed(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/use_allowlist/set", params: .named(["use": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getMaxPlayers() async throws -> Int {
		let response = try await request("minecraft:serversettings/max_players")
		return try response.recode(to: Int.self)
	}

	public func setMaxPlayers(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/max_players/set", params: .named(["max": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getPauseWhenEmptySeconds() async throws -> Int {
		let response = try await request("minecraft:serversettings/pause_when_empty_seconds")
		return try response.recode(to: Int.self)
	}

	public func setPauseWhenEmptySeconds(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/pause_when_empty_seconds/set", params: .named(["seconds": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getPlayerIdleTimeout() async throws -> Int {
		let response = try await request("minecraft:serversettings/player_idle_timeout")
		return try response.recode(to: Int.self)
	}

	public func setPlayerIdleTimeout(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/player_idle_timeout/set", params: .named(["seconds": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getAllowFlight() async throws -> Bool {
		let response = try await request("minecraft:serversettings/allow_flight")
		return try response.recode(to: Bool.self)
	}

	public func setAllowFlight(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/allow_flight/set", params: .named(["allow": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getMOTD() async throws -> String {
		let response = try await request("minecraft:serversettings/motd")
		return try response.recode(to: String.self)
	}

	public func setMOTD(to value: String) async throws -> String {
		let response = try await request("minecraft:serversettings/motd/set", params: .named(["message": JSONValue(recoding: value)]))
		return try response.recode(to: String.self)
	}

	public func getSpawnProtectionRadius() async throws -> Int {
		let response = try await request("minecraft:serversettings/spawn_protection_radius")
		return try response.recode(to: Int.self)
	}

	public func setSpawnProtectionRadius(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/spawn_protection_radius/set", params: .named(["radius": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getForceGamemode() async throws -> Bool {
		let response = try await request("minecraft:serversettings/force_game_mode")
		return try response.recode(to: Bool.self)
	}

	public func setForceGamemode(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/force_game_mode/set", params: .named(["force": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getGamemode() async throws -> Gamemode {
		let response = try await request("minecraft:serversettings/game_mode")
		return Gamemode(rawValue: try response.recode(to: String.self)) ?? .adventure
	}

	public func setGamemode(to value: Gamemode) async throws -> Gamemode {
		let response = try await request("minecraft:serversettings/game_mode/set", params: .named(["mode": JSONValue(recoding: value.rawValue)]))
		return Gamemode(rawValue: try response.recode(to: String.self)) ?? .adventure
	}

	public func getViewDistance() async throws -> Int {
		let response = try await request("minecraft:serversettings/view_distance")
		return try response.recode(to: Int.self)
	}

	public func setViewDistance(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/view_distance/set", params: .named(["distance": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getSimulationDistance() async throws -> Int {
		let response = try await request("minecraft:serversettings/simulation_distance")
		return try response.recode(to: Int.self)
	}

	public func setSimulationDistance(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/simulation_distance/set", params: .named(["distance": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getAcceptTransfers() async throws -> Bool {
		let response = try await request("minecraft:serversettings/accept_transfers")
		return try response.recode(to: Bool.self)
	}

	public func setAcceptTransfers(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/accept_transfers/set", params: .named(["accept": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getStatusHeatbeatInterval() async throws -> Int {
		let response = try await request("minecraft:serversettings/status_heartbeat_interval")
		return try response.recode(to: Int.self)
	}

	public func setStatusHeatbeatInterval(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/status_heartbeat_interval/set", params: .named(["seconds": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getOperatorUserPermissionLevel() async throws -> Int {
		let response = try await request("minecraft:serversettings/operator_user_permission_level")
		return try response.recode(to: Int.self)
	}

	public func setOperatorUserPermissionLevel(to value: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/operator_user_permission_level/set", params: .named(["level": JSONValue(recoding: value)]))
		return try response.recode(to: Int.self)
	}

	public func getHideOnlinePlayers() async throws -> Bool {
		let response = try await request("minecraft:serversettings/hide_online_players")
		return try response.recode(to: Bool.self)
	}

	public func setHideOnlinePlayers(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/hide_online_players/set", params: .named(["hide": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getStatusReplies() async throws -> Bool {
		let response = try await request("minecraft:serversettings/status_replies")
		return try response.recode(to: Bool.self)
	}

	public func setStatusReplies(to value: Bool) async throws -> Bool {
		let response = try await request("minecraft:serversettings/status_replies/set", params: .named(["enable": JSONValue(recoding: value)]))
		return try response.recode(to: Bool.self)
	}

	public func getEntityBroadcastRange() async throws -> Int {
		let response = try await request("minecraft:serversettings/entity_broadcast_range")
		return try response.recode(to: Int.self)
	}

	public func setEntityBroadcastRange(to percentagePoints: Int) async throws -> Int {
		let response = try await request("minecraft:serversettings/entity_broadcast_range/set", params: .named(["percentage_points": JSONValue(recoding: percentagePoints)]))
		return try response.recode(to: Int.self)
	}

	public func getGamerules() async throws -> [TypedGamerule] {
		let response = try await request("minecraft:gamerules")
		return try response.recode(to: [TypedGamerule].self)
	}

	public func updateGamerule(_ gamerule: UntypedGamerule) async throws -> TypedGamerule {
		let response = try await request("minecraft:gamerules/update", params: .named(["gamerule": JSONValue(recoding: gamerule)]))
		return try response.recode(to: TypedGamerule.self)
	}

	private func handleIncomingMessage(_ message: JSONRPCResponse) throws {
		guard let continuation = self.continuations[message.id ?? -1] else {
			switch message {
			case let .notification(request):
				try self.handleNotification(request)
			default:
				print("Got unexpected non-notification message \(message)")
			}
			return
		}
		self.removeContinuation(forId: message.id ?? -1)
		switch message {
		case let .result(_, result):
			continuation.resume(returning: result)
		case let .error(_, error):
			continuation.resume(throwing: error)
		case .notification:
			fatalError("Got a notification with an id, this should never be possible")
		}
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

	private var notificationQueue = [Notification]()
	private var nextNotificationContinuation: CheckedContinuation<Void, Swift.Error>? = nil

	private func setNextNotificationContinuation(to continuation: CheckedContinuation<Void, Swift.Error>) throws {
		guard self.nextNotificationContinuation == nil else {
			throw Error.alreadyWaitingForNotification
		}
		nextNotificationContinuation = continuation
	}

	private func handleNotification(_ notification: JSONRPCRequest) throws {
		guard let parsedNotification = try Notification(parsing: notification) else {
			return
		}
		notificationQueue.append(parsedNotification)
		if let nextNotificationContinuation {
			self.nextNotificationContinuation = nil
			nextNotificationContinuation.resume()
		}
	}

	private var connection: WebsocketConnection<JSONRPCRequest, JSONRPCResponse>!

	private func handleDisconnection(_ code: Int, reason: Data?) {
		if let nextNotificationContinuation {
			self.nextNotificationContinuation = nil
			nextNotificationContinuation.resume(throwing: Error.disconnected(code: code, reason: reason))
		}
	}
}