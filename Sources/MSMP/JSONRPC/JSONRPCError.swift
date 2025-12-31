struct JSONRPCError: Codable, Error {
	let code: Int
	let message: String
	let data: JSONValue?
}