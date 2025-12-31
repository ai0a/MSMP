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

	public func getStatus() async throws -> ServerState {
		let response = try await request("minecraft:server/status")
		return try response.recode(to: ServerState.self)
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