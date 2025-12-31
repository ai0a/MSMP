import Testing
import MSMP

@Test func getInfo() async throws {
	let connection = try await Connection(to: "localhost", port: 1337, secret: "H4QULuJARuL1xICrINfq5wWqoChwkwzWXErTCFeC")
	#expect(try await connection.getStatus() == ServerState(players: nil, isStarted: true, version: MSMP.Version(protocol: 773, name: "1.21.9")))
}