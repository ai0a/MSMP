import Testing
import Foundation
import MSMP

@Suite struct Tests {
	let connection: Connection

	let ip = "localhost"

	init() async throws {
		connection = try await Connection(to: ip, port: 1337, secret: "H4QULuJARuL1xICrINfq5wWqoChwkwzWXErTCFeC")
	}

	/// What notifications will naturally show up over the course of the entire test suite?
	enum NaturalNotification: CaseIterable {
		case allowlistAdded
		case allowlistRemoved
		case bansAdded
		// case bansRemoved
		case ipBansAdded
		case ipBansRemoved
		case operatorAdded
		case operatorRemoved
		case gamerulesUpdated
		case playerJoined
		case serverSaved
		case serverSaving
		case serverStopping
		case playerLeft
	}

	@Test func testNotifications() async throws {
		var seenNotifications = Set<NaturalNotification>()
		while let notification = try? await connection.nextNotification {
			guard let expectedNotificationType: NaturalNotification = switch notification {
			case .allowlistAdded: .allowlistAdded
			case .allowlistRemoved: .allowlistRemoved
			case .bansAdded: .bansAdded
			// case .bansRemoved: .bansRemoved
			case .ipBansAdded: .ipBansAdded
			case .ipBansRemoved: .ipBansRemoved
			case .operatorAdded: .operatorAdded
			case .operatorRemoved: .operatorRemoved
			case .gamerulesUpdated: .gamerulesUpdated
			case .playerJoined: .playerJoined
			case .serverSaved: .serverSaved
			case .serverSaving: .serverSaving
			case .serverStopping: .serverStopping
			case .playerLeft: .playerLeft
			default: nilFor(notification)
			} else {
				continue
			}
			seenNotifications.insert(expectedNotificationType)
		}
		for expected in NaturalNotification.allCases {
			#expect(seenNotifications.contains(expected))
		}
	}

	func nilFor<T, U>(_ t: T) -> U? {
		print("UNEXPECTED NOTIFICATION", t)
		return nil
	}

	@Test func testServer() async throws {
		guard let player = try await TestPlayer(ip: ip, port: 25565, username: "testServer") else {
			#expect(Bool(false))
			return
		}
		try await Task.sleep(for: .seconds(1))
		
		let status = try await connection.getStatus()
		#expect(status.players?.contains { $0.name == "testServer" } ?? false)
		#expect(status == ServerState(players: status.players, isStarted: true, version: MSMP.Version(protocol: 773, name: "1.21.9")))
		#expect(try await connection.save(flush: false))
		#expect(try await connection.save(flush: true))
		try await withThrowingTaskGroup(of: Bool.self) { taskGroup in
			taskGroup.addTask {
				let (receivedMessage, isOverlay) = await player.nextChatMessage()
				return receivedMessage == "Test message" && !isOverlay
			}
			taskGroup.addTask {
				try await Task.sleep(for: .seconds(0.1))
				return try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: false, message: "Test message"))
			}
			for try await result in taskGroup {
				#expect(result)
			}
		}
		try await withThrowingTaskGroup(of: Bool.self) { taskGroup in
			taskGroup.addTask {
				let (receivedMessage, isOverlay) = await player.nextChatMessage()
				return receivedMessage == "Test overlay" && isOverlay
			}
			taskGroup.addTask {
				try await Task.sleep(for: .seconds(0.1))
				return try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: true, message: "Test overlay"))
			}
			for try await result in taskGroup {
				#expect(result)
			}
		}

		try await player.disconnect()

		try await Task.sleep(for: .seconds(5))
		#expect(try await connection.stop())
	}

	@Test func testAllowlist() async throws {
		let originalAllowlist = try await connection.getAllowlist()
		#expect(try await connection.setAllowlist(to: [
			Player(name: "herobrine"),
			Player(name: "steve"),
			Player(name: ".player1", id: UUID().uuidString)
		]) == [MSMP.Player(name: "Herobrine", id: Optional("f84c6a79-0a4e-45e0-879b-cd49ebd4c4e2")), MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7"))])

		#expect(try await connection.addToAllowlist(Player(name: "jeb_")) == [MSMP.Player(name: "Herobrine", id: Optional("f84c6a79-0a4e-45e0-879b-cd49ebd4c4e2")), MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7")), MSMP.Player(name: "jeb_", id: Optional("853c80ef-3c37-49fd-aa49-938b674adae6"))])

		#expect(try await connection.removeFromAllowlist(Player(name: "herobrine")) == [MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7")), MSMP.Player(name: "jeb_", id: Optional("853c80ef-3c37-49fd-aa49-938b674adae6"))])

		#expect(try await connection.clearAllowlist() == [])

		#expect(try await connection.setAllowlist(to: originalAllowlist) == originalAllowlist)
	}

	@Test func testBanlist() async throws {
		let originalBanlist = try await connection.getBanlist()
		#expect(try await connection.setBanlist(to: [
			.init(reason: "Get banned lmao!", source: "Automated test", player: Player(name: "jeb_")),
			.init(reason: "Disgusting vile rule breaker!", source: "Automated test", player: Player(name: "steve")),
		]) == [MSMP.UserBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", player: MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7"))), MSMP.UserBan(reason: "Get banned lmao!", expires: nil, source: "Automated test", player: MSMP.Player(name: "jeb_", id: Optional("853c80ef-3c37-49fd-aa49-938b674adae6")))])

		#expect(try await connection.addToBanlist(.init(reason: "Crimes against humanity", source: "Automated test", player: "geminitay")) == [MSMP.UserBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", player: MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7"))), MSMP.UserBan(reason: "Crimes against humanity", expires: nil, source: "Automated test", player: MSMP.Player(name: "GeminiTay", id: Optional("5a1839d2-cecc-4c85-aa08-b346f9f772a1"))), MSMP.UserBan(reason: "Get banned lmao!", expires: nil, source: "Automated test", player: MSMP.Player(name: "jeb_", id: Optional("853c80ef-3c37-49fd-aa49-938b674adae6")))])

		#expect(try await connection.removeFromBanlist("jeb_") == [MSMP.UserBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", player: MSMP.Player(name: "Steve", id: Optional("8667ba71-b85a-4004-af54-457a9734eed7"))), MSMP.UserBan(reason: "Crimes against humanity", expires: nil, source: "Automated test", player: MSMP.Player(name: "GeminiTay", id: Optional("5a1839d2-cecc-4c85-aa08-b346f9f772a1")))])

		#expect(try await connection.clearBanlist() == [])
		
		#expect(try await connection.setBanlist(to: originalBanlist) == originalBanlist)
	}

	@Test func testIPBanlist() async throws {
		let originalBanlist = try await connection.getIPBanlist()
		#expect(try await connection.setIPBanlist(to: [
			.init(reason: "Get banned lmao!", source: "Automated test", ip: "192.192.0.1"),
			.init(reason: "Disgusting vile rule breaker!", source: "Automated test", ip: "192.192.0.2"),
		]) == [MSMP.IPBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", ip: "192.192.0.2"), MSMP.IPBan(reason: "Get banned lmao!", expires: nil, source: "Automated test", ip: "192.192.0.1")])

		#expect(try await connection.addToIPBanlist(.init(reason: "Crimes against humanity", source: "Automated test", ip: "192.192.0.3")) == [MSMP.IPBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", ip: "192.192.0.2"), MSMP.IPBan(reason: "Get banned lmao!", expires: nil, source: "Automated test", ip: "192.192.0.1")])

		#expect(try await connection.removeFromIPBanlist("192.192.0.1") == [MSMP.IPBan(reason: "Disgusting vile rule breaker!", expires: nil, source: "Automated test", ip: "192.192.0.2")])

		#expect(try await connection.clearIPBanlist() == [])
		
		#expect(try await connection.setIPBanlist(to: originalBanlist) == originalBanlist)
	}

	@Test func testPlayers() async throws {
		let players = try await connection.getAllConnectedPlayers()
		guard players.count > 0 else {
			return
		}
		// TODO: Actually test this for proper response, right now though the ip ban tests are interfering
		let _ = try await connection.kickPlayers([.init(player: players[0], message: "Get kicked loser")])
	}

	@Test func testOperators() async throws {
		let originalOperators = try await connection.getOpList()
		#expect(try await connection.setOpList(to: [.init(permissionLevel: 1, bypassesPlayerLimit: true, player: "herobrine")]) == [MSMP.Operator(permissionLevel: 1, bypassesPlayerLimit: true, player: MSMP.Player(name: "Herobrine", id: Optional("f84c6a79-0a4e-45e0-879b-cd49ebd4c4e2")))])

		#expect(try await connection.addToOpList(Operator(permissionLevel: 2, bypassesPlayerLimit: false, player: "geminitay")) == [MSMP.Operator(permissionLevel: 1, bypassesPlayerLimit: true, player: MSMP.Player(name: "Herobrine", id: Optional("f84c6a79-0a4e-45e0-879b-cd49ebd4c4e2"))), MSMP.Operator(permissionLevel: 2, bypassesPlayerLimit: false, player: MSMP.Player(name: "GeminiTay", id: Optional("5a1839d2-cecc-4c85-aa08-b346f9f772a1")))])

		#expect(try await connection.removeFromOpList("herobrine") == [MSMP.Operator(permissionLevel: 2, bypassesPlayerLimit: false, player: MSMP.Player(name: "GeminiTay", id: Optional("5a1839d2-cecc-4c85-aa08-b346f9f772a1")))])

		#expect(try await connection.clearOpList() == [])
		
		#expect(try await connection.setOpList(to: originalOperators) == originalOperators)
	}

	@Test func testServersettings() async throws {
		#expect(try await connection.getAutosaveIsEnabled())
		#expect(try await connection.setAutosaveIsEnabled(to: false) == false)
		#expect(try await connection.setAutosaveIsEnabled(to: true))

		#expect(try await connection.getDifficulty() == .easy)
		#expect(try await connection.setDifficulty(to: .peaceful) == .peaceful)
		#expect(try await connection.setDifficulty(to: .normal) == .normal)
		#expect(try await connection.setDifficulty(to: .hard) == .hard)
		#expect(try await connection.setDifficulty(to: .easy) == .easy)

		#expect(try await connection.getAllowlistIsEnforced() == false)
		#expect(try await connection.setAllowlistIsEnforced(to: true))
		#expect(try await connection.setAllowlistIsEnforced(to: false) == false)

		#expect(try await connection.getAllowlistIsUsed() == false)
		#expect(try await connection.setAllowlistIsUsed(to: true))
		#expect(try await connection.setAllowlistIsUsed(to: false) == false)

		#expect(try await connection.getMaxPlayers() == 20)
		#expect(try await connection.setMaxPlayers(to: 40) == 40)
		#expect(try await connection.setMaxPlayers(to: 20) == 20)

		#expect(try await connection.getPauseWhenEmptySeconds() == 60)
		#expect(try await connection.setPauseWhenEmptySeconds(to: 40) == 40)
		#expect(try await connection.setPauseWhenEmptySeconds(to: 60) == 60)

		#expect(try await connection.getPlayerIdleTimeout() == 0)
		#expect(try await connection.setPlayerIdleTimeout(to: 40) == 40)
		#expect(try await connection.setPlayerIdleTimeout(to: 0) == 0)

		#expect(try await connection.getAllowFlight() == false)
		#expect(try await connection.setAllowFlight(to: true))
		#expect(try await connection.setAllowFlight(to: false) == false)

		#expect(try await connection.getMOTD() == "A Minecraft Server")
		#expect(try await connection.setMOTD(to: "Epic MOTD") == "Epic MOTD")
		#expect(try await connection.setMOTD(to: "A Minecraft Server") == "A Minecraft Server")

		#expect(try await connection.getSpawnProtectionRadius() == 16)
		#expect(try await connection.setSpawnProtectionRadius(to: 20) == 20)
		#expect(try await connection.setSpawnProtectionRadius(to: 16) == 16)

		#expect(try await connection.getForceGamemode() == false)
		#expect(try await connection.setForceGamemode(to: true))
		#expect(try await connection.setForceGamemode(to: false) == false)

		#expect(try await connection.getGamemode() == .survival)
		#expect(try await connection.setGamemode(to: .creative) == .creative)
		#expect(try await connection.setGamemode(to: .adventure) == .adventure)
		#expect(try await connection.setGamemode(to: .spectator) == .spectator)
		#expect(try await connection.setGamemode(to: .survival) == .survival)

		#expect(try await connection.getViewDistance() == 10)
		#expect(try await connection.setViewDistance(to: 20) == 20)
		#expect(try await connection.setViewDistance(to: 10) == 10)

		#expect(try await connection.getSimulationDistance() == 10)
		#expect(try await connection.setSimulationDistance(to: 20) == 20)
		#expect(try await connection.setSimulationDistance(to: 10) == 10)

		#expect(try await connection.getAcceptTransfers() == false)
		#expect(try await connection.setAcceptTransfers(to: true))
		#expect(try await connection.setAcceptTransfers(to: false) == false)

		#expect(try await connection.getStatusHeatbeatInterval() == 0)
		#expect(try await connection.setStatusHeatbeatInterval(to: 20) == 20)
		#expect(try await connection.setStatusHeatbeatInterval(to: 0) == 0)

		#expect(try await connection.getOperatorUserPermissionLevel() == 4)
		#expect(try await connection.setOperatorUserPermissionLevel(to: 5) == 5)
		#expect(try await connection.setOperatorUserPermissionLevel(to: 4) == 4)

		#expect(try await connection.getHideOnlinePlayers() == false)
		#expect(try await connection.setHideOnlinePlayers(to: true))
		#expect(try await connection.setHideOnlinePlayers(to: false) == false)

		#expect(try await connection.getStatusReplies())
		#expect(try await connection.setStatusReplies(to: false) == false)
		#expect(try await connection.setStatusReplies(to: true))

		#expect(try await connection.getEntityBroadcastRange() == 100)
		#expect(try await connection.setEntityBroadcastRange(to: 20) == 20)
		#expect(try await connection.setEntityBroadcastRange(to: 100) == 100)
	}

	@Test func testGamerules() async throws {
		#expect(try await connection.getGamerules() == [MSMP.TypedGamerule(key: "allowEnteringNetherUsingPortals", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "allowFireTicksAwayFromPlayer", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "announceAdvancements", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "blockExplosionDropDecay", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "commandBlockOutput", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "commandBlocksEnabled", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "commandModificationBlockLimit", value: MSMP.TypedGamerule.Value.integer(32768)), MSMP.TypedGamerule(key: "disableElytraMovementCheck", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "disablePlayerMovementCheck", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "disableRaids", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "doDaylightCycle", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doEntityDrops", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doFireTick", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doImmediateRespawn", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "doInsomnia", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doLimitedCrafting", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "doMobLoot", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doMobSpawning", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doPatrolSpawning", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doTileDrops", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doTraderSpawning", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doVinesSpread", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doWardenSpawning", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "doWeatherCycle", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "drowningDamage", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "enderPearlsVanishOnDeath", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "fallDamage", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "fireDamage", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "forgiveDeadPlayers", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "freezeDamage", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "globalSoundEvents", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "keepInventory", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "lavaSourceConversion", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "locatorBar", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "logAdminCommands", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "maxCommandChainLength", value: MSMP.TypedGamerule.Value.integer(65536)), MSMP.TypedGamerule(key: "maxCommandForkCount", value: MSMP.TypedGamerule.Value.integer(65536)), MSMP.TypedGamerule(key: "maxEntityCramming", value: MSMP.TypedGamerule.Value.integer(24)), MSMP.TypedGamerule(key: "mobExplosionDropDecay", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "mobGriefing", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "naturalRegeneration", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "playersNetherPortalCreativeDelay", value: MSMP.TypedGamerule.Value.integer(0)), MSMP.TypedGamerule(key: "playersNetherPortalDefaultDelay", value: MSMP.TypedGamerule.Value.integer(80)), MSMP.TypedGamerule(key: "playersSleepingPercentage", value: TypedGamerule.Value.integer(100)), MSMP.TypedGamerule(key: "projectilesCanBreakBlocks", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "pvp", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "randomTickSpeed", value: MSMP.TypedGamerule.Value.integer(3)), MSMP.TypedGamerule(key: "reducedDebugInfo", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "sendCommandFeedback", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "showDeathMessages", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "snowAccumulationHeight", value: MSMP.TypedGamerule.Value.integer(1)), MSMP.TypedGamerule(key: "spawnMonsters", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "spawnRadius", value: MSMP.TypedGamerule.Value.integer(10)), MSMP.TypedGamerule(key: "spawnerBlocksEnabled", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "spectatorsGenerateChunks", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "tntExplodes", value: MSMP.TypedGamerule.Value.boolean(true)), MSMP.TypedGamerule(key: "tntExplosionDropDecay", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "universalAnger", value: MSMP.TypedGamerule.Value.boolean(false)), MSMP.TypedGamerule(key: "waterSourceConversion", value: MSMP.TypedGamerule.Value.boolean(true))])
		#expect(try await connection.updateGamerule(UntypedGamerule(key: "allowEnteringNetherUsingPortals", value: "false")) == TypedGamerule(key: "allowEnteringNetherUsingPortals", value: MSMP.TypedGamerule.Value.boolean(false)))
		#expect(try await connection.updateGamerule(UntypedGamerule(key: "allowEnteringNetherUsingPortals", value: "true")) == TypedGamerule(key: "allowEnteringNetherUsingPortals", value: MSMP.TypedGamerule.Value.boolean(true)))
	}
}