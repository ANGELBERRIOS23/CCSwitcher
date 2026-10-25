// Isolated persistence tests must not create, rotate, or remove user app logs.
struct FileLog: Sendable {
    init(_ category: String) { }
    func info(_ message: String) { }
    func warning(_ message: String) { }
    func error(_ message: String) { }
    func debug(_ message: String) { }
}
