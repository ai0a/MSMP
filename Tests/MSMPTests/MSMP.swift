import Testing
import MSMP

@Test func testServer() async throws {
	let connection = try await Connection(to: "localhost", port: 1337, secret: "H4QULuJARuL1xICrINfq5wWqoChwkwzWXErTCFeC")
	let status = try await connection.getStatus()
	#expect(status == ServerState(players: status.players, isStarted: true, version: MSMP.Version(protocol: 773, name: "1.21.9")))
	#expect(try await connection.save(flush: false))
	#expect(try await connection.save(flush: true))
	#expect(try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: true, message: "Test message")))
	print("All players should have seen a chat message saying 'Test message'")
	#expect(try await connection.send(systemMessage: .init(receivingPlayers: status.players, isOverlay: false, message: "Test overlay")))
	print("All players should have seen an overlay message saying 'Test overlay'")
}