import Foundation
import OSLog

final class AppLogger {
    static let shared = AppLogger()

    private let logger = Logger(subsystem: "com.ananaschan.smbplayer", category: "AppLog")
    private let lock = NSLock()
    private let fileURL: URL
    private var fileHandle: FileHandle?

    private init() {
        let logsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        fileURL = logsDirectory.appendingPathComponent("app.log")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: fileURL)
        fileHandle?.seekToEndOfFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    var logFileURL: URL {
        fileURL
    }

    func log(_ message: String) {
        let line = "\(Self.timestamp()) \(message)\n"
        logger.info("\(message, privacy: .public)")
        lock.lock()
        defer { lock.unlock() }
        guard let data = line.data(using: .utf8) else {
            return
        }
        fileHandle?.write(data)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
