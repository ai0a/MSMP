public enum Notification: Equatable, Sendable {
	case serverStarted
	case serverStopping
	case serverSaving
	case serverSaved
	case serverStatus(ServerState)
	case serverActivity
	case playerJoined(Player)
	case playerLeft(Player)
	case operatorAdded(Operator)
	case operatorRemoved(Operator)
	case allowlistAdded(Player)
	case allowlistRemoved(Player)
	case ipBansAdded(IPBan)
	case ipBansRemoved(String)
	case bansAdded(UserBan)
	case bansRemoved(Player)
	case gamerulesUpdated(TypedGamerule)
	
	init?(parsing request: JSONRPCRequest) throws {
		switch request.method {
		case "minecraft:notification/server/started":
			self = .serverStarted
		case "minecraft:notification/server/stopping":
			self = .serverStopping
		case "minecraft:notification/server/saving":
			self = .serverSaving
		case "minecraft:notification/server/saved":
			self = .serverSaved
		case "minecraft:notification/server/status":
			guard let params = request.params, let stateValue = params["status", orPositional: 0] else {
				return nil
			}
			self = .serverStatus(try stateValue.recode(to: ServerState.self))
		case "minecraft:notification/server/activity":
			self = .serverActivity
		case "minecraft:notification/players/joined":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .playerJoined(try stateValue.recode(to: Player.self))
		case "minecraft:notification/players/left":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .playerLeft(try stateValue.recode(to: Player.self))
		case "minecraft:notification/operators/added":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .operatorAdded(try stateValue.recode(to: Operator.self))
		case "minecraft:notification/operators/removed":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .operatorRemoved(try stateValue.recode(to: Operator.self))
		case "minecraft:notification/allowlist/added":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .allowlistAdded(try stateValue.recode(to: Player.self))
		case "minecraft:notification/allowlist/removed":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .allowlistRemoved(try stateValue.recode(to: Player.self))
		case "minecraft:notification/ip_bans/added":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .ipBansAdded(try stateValue.recode(to: IPBan.self))
		case "minecraft:notification/ip_bans/removed":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .ipBansRemoved(try stateValue.recode(to: String.self))
		case "minecraft:notification/bans/added":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .bansAdded(try stateValue.recode(to: UserBan.self))
		case "minecraft:notification/bans/removed":
			guard let params = request.params, let stateValue = params["player", orPositional: 0] else {
				return nil
			}
			self = .bansRemoved(try stateValue.recode(to: Player.self))
		case "minecraft:notification/gamerules/updated":
			guard let params = request.params, let stateValue = params["gamerule", orPositional: 0] else {
				return nil
			}
			self = .gamerulesUpdated(try stateValue.recode(to: TypedGamerule.self))
		default:
			print("Unknown notification request method from \(request)")
			return nil
		}
	}
}