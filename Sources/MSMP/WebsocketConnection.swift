import Foundation

final actor WebsocketConnection<Request: Codable, Response: Codable>: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate {
	private let logAllPackets = false
	private let certificate: Data?
	
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

	public init(
		url: URLRequest,
		certificate: Data? = nil,
		receiveHandler: @escaping ReceiveHandler,
		connectHandler: @escaping ConnectHandler,
		disconnectHandler: @escaping DisconnectHandler
	) {
		self.certificate = certificate
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

	nonisolated func urlSession(
		_ session: URLSession,
		didReceive challenge: URLAuthenticationChallenge,
		completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
	) {
		guard let certificate else {
			completionHandler(.performDefaultHandling, nil)
			return
		}
		guard
			let trust = challenge.protectionSpace.serverTrust,
			SecTrustGetCertificateCount(trust) > 0,
			let serverCertificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate]
		else {
			completionHandler(.cancelAuthenticationChallenge, nil)
			return
		}

		// Extract and convert the server's certificates into `Data` objects
		// for comparison with pinned certificates.
		let serverCertificatesData = serverCertificates.map { SecCertificateCopyData($0) as Data }

		// Check if any of the server's certificates match the pinned certificates.
		if serverCertificatesData.contains(where: { $0 == certificate }) {
			// A match was found! Use `.useCredential` to trust the server and proceed with the request.
			completionHandler(.useCredential, URLCredential(trust: trust))
		} else {
			// No match was found. Cancel the authentication challenge to reject the server.
			completionHandler(.cancelAuthenticationChallenge, nil)
		}
	}
}