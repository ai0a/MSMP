import Foundation

final actor WebsocketConnection<Request: Codable, Response: Codable>: NSObject, URLSessionWebSocketDelegate {
	private let logAllPackets = false
	
	public typealias ReceiveHandler = @Sendable (Response) async throws -> Void
	public typealias ConnectHandler = @Sendable () async -> Void
	public typealias DisconnectHandler = @Sendable (Int, Data?) async -> Void
	
	private var webSocketTask: URLSessionWebSocketTask!
	private let receiveHandler: ReceiveHandler
	private let connectHandler: ConnectHandler
	private let disconnectHandler: DisconnectHandler

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	public var isActive: Bool { webSocketTask.state == .running }
	public var closeCode: Int { webSocketTask.closeCode.rawValue }

	public func send(_ message: Request) async throws {
		if logAllPackets {
			print("\u{001B}[36mOUTBOUND\u{001B}[0m")
			print("\t\(message)")
		}
		let data = try encoder.encode(message)
		try await webSocketTask.send(.string(String(decoding: data, as: UTF8.self)))
	}

	public func disconnect(_ closeCode: URLSessionWebSocketTask.CloseCode = .goingAway) {
		webSocketTask.cancel(with: closeCode, reason: nil)
	}

	public init(url: URLRequest, receiveHandler: @escaping ReceiveHandler, connectHandler: @escaping ConnectHandler, disconnectHandler: @escaping DisconnectHandler) {
		self.receiveHandler = receiveHandler
		self.connectHandler = connectHandler
		self.disconnectHandler = disconnectHandler
		super.init()
		let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
		webSocketTask = session.webSocketTask(with: url)
		webSocketTask.resume()
		Task {
			await listen()
		}
	}

	private nonisolated func listen() async {
		while await isActive {
			do {
				let wsMessage = try await webSocketTask.receive()
				let decodedMessage = try decoder.decode(Response.self, from: dataFor(wsMessage))
				if logAllPackets {
					print("\u{001B}[36mINBOUND\u{001B}[0m")
					print("\t\(decodedMessage)")
				}
				try await receiveHandler(decodedMessage)
			} catch let error {
				if logAllPackets {
					print("\u{001B}[37mERROR\u{001B}[0m")
					print("\tGot error \(error) in listening for event")
				}
			}
		}
		await disconnectHandler(0, nil)
	}

	private nonisolated func dataFor(_ message: URLSessionWebSocketTask.Message) -> Data {
		switch message {
		case let .data(data):
			return data
		case let .string(string):
			return string.data(using: .utf8)! // utf8 never fails
		default:
			fatalError("Unknown websocket message type \(message)")
		}
	}

	nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		Task {
			await disconnectHandler(closeCode.rawValue, reason)
		}
	}

	nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		Task {
			await connectHandler()
		}
	}
}