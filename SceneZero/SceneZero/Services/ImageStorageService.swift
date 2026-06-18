import Foundation
import UIKit

struct ImageStorageService {
    enum StorageError: Error {
        case couldNotEncodeImage
        case couldNotCreateDirectory
    }

    private let folderName = "LookbookImages"

    func save(_ image: UIImage) throws -> String {
        guard let data = image.pngData() else {
            throw StorageError.couldNotEncodeImage
        }

        let directory = try imageDirectory()
        let fileName = "\(UUID().uuidString).png"
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return "\(folderName)/\(fileName)"
    }

    func load(relativePath: String) -> UIImage? {
        guard let url = try? baseDirectory().appendingPathComponent(relativePath) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    func fileURL(relativePath: String) -> URL? {
        try? baseDirectory().appendingPathComponent(relativePath)
    }

    func delete(relativePath: String) {
        guard let url = try? baseDirectory().appendingPathComponent(relativePath) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func imageDirectory() throws -> URL {
        let directory = try baseDirectory().appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func baseDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StorageError.couldNotCreateDirectory
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
