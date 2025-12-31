import Testing
import Foundation
import MSMP

@Suite struct Tests {
	let connection: Connection

	init() async throws {
		connection = try await Connection(to: "localhost", port: 1337, secret: "H4QULuJARuL1xICrINfq5wWqoChwkwzWXErTCFeC")
	}

	@Test func testServer() async throws {
		let status = try await connection.getStatus()
		#expect(status == ServerState(players: status.players, isStarted: true, version: MSMP.Version(protocol: 773, name: "1.21.9")))
		#expect(try await connection.save(flush: false))
		#expect(try await connection.save(flush: true))
		#expect(try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: false, message: "Test message")))
		print("All players should have seen a chat message saying 'Test message'")
		#expect(try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: true, message: "Test overlay")))
		print("All players should have seen an overlay message saying 'Test overlay'")
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
}