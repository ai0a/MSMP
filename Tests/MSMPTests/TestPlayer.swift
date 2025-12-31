import Foundation
import MinecraftProtocol

struct TestPlayer {
	private let connection: Connection
	
	init?(ip: String, port: UInt16, username: String) async throws {
		connection = try await Connection(to: ServerLocation(ip: ip, port: port))

		let handshakePacket = C2SHandshakePacket(protocolVersion: .latest, ip: ip, port: port, nextState: .login)
		try await connection.send(handshakePacket)
		await connection.changeState(to: .login)
		let loginStartPacket = C2SLoginStartPacket(name: username, playerUUID: UUID())
		try await connection.send(loginStartPacket)
		guard var serverResponse = await connection.nextPacket(timeout: 10) else {
			return nil
		}
		if let compressionPacket = serverResponse as? S2CSetCompressionPacket {
			await connection.changeCompressionThreshold(to: compressionPacket.threshold)
			guard let newServerResponse = await connection.nextPacket(timeout: 10) else {
				return nil
			}
			serverResponse = newServerResponse
		}
		guard let _ = serverResponse as? S2CLoginSuccessPacket else {
			return nil
		}
		try await connection.send(C2SLoginAcknowledgedPacket())
		await connection.changeState(to: .configuration)
		for await packet in connection {
			if let knownPacks = packet as? S2CKnownPacksPacket {
				try await connection.send(C2SKnownPacksPacket(packs: knownPacks.packs))
			} else if packet is S2CFinishConfigurationPacket {
				try await connection.send(C2SAcknowledgeFinishConfigurationPacket())
				await connection.changeState(to: .play)
				break
			}
		}
	}

	func nextChatMessage() async -> (String?, Bool) {
		for await packet in connection {
			if let chat = packet as? S2CSystemChatMessage {
				return (chat.content.text, chat.isOverlay)
			}
		}
		return (nil, false)
	}

	func disconnect() async throws {
		try await connection.close()
	}
}