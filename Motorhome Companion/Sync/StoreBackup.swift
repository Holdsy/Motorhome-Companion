import Foundation
import SQLite3

/// Take a consistent SQLite snapshot (including committed WAL contents) before
/// the first cloud-ready migration. Never alter or remove the original store.
enum StoreBackup {
    static func beforeCloudMigration(at store: URL) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: store.path) else { return }
        let folder = store.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let backup = folder.appendingPathComponent("Before-iCloud-v1.sqlite")
        guard !files.fileExists(atPath: backup.path) else { return }
        let temporary = folder.appendingPathComponent("migration-\(UUID()).sqlite")
        defer { try? files.removeItem(at: temporary) }
        var source: OpaquePointer?
        var destination: OpaquePointer?
        defer { if let source { sqlite3_close(source) }; if let destination { sqlite3_close(destination) } }
        guard sqlite3_open_v2(store.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open(temporary.path, &destination) == SQLITE_OK,
              let transfer = sqlite3_backup_init(destination, "main", source, "main") else { throw BackupError.failed }
        let result = sqlite3_backup_step(transfer, -1)
        let finish = sqlite3_backup_finish(transfer)
        guard result == SQLITE_DONE, finish == SQLITE_OK else { throw BackupError.failed }
        // Close before publishing the completed backup.
        sqlite3_close(destination); destination = nil
        try files.moveItem(at: temporary, to: backup)
    }
    enum BackupError: LocalizedError {
        case failed
        var errorDescription: String? { "Couldn’t back up the existing records before the iCloud upgrade. Close any other app windows and try again. The original database has not been reset." }
    }
}
