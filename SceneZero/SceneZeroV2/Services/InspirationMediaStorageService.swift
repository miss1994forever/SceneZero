import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct InspirationMediaStorageService {
    enum MediaKind: String {
        case audio
        case video
    }

    enum StorageError: LocalizedError {
        case unsupportedFile
        case couldNotCreateDirectory

        var errorDescription: String? {
            switch self {
            case .unsupportedFile: "不支持这个媒体文件。"
            case .couldNotCreateDirectory: "无法创建媒体存储目录。"
            }
        }
    }

    private let rootFolder = "InspirationMedia"

    func importFile(at sourceURL: URL, kind: MediaKind) throws -> String {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = sourceURL.pathExtension.isEmpty
            ? defaultExtension(for: kind)
            : sourceURL.pathExtension.lowercased()
        let directory = try mediaDirectory(for: kind)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = directory.appending(path: fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return "\(rootFolder)/\(kind.rawValue)/\(fileName)"
    }

    func commitRecordedAudio(at temporaryURL: URL) throws -> String {
        try importFile(at: temporaryURL, kind: .audio)
    }

    func fileURL(relativePath: String) -> URL? {
        try? baseDirectory().appending(path: relativePath)
    }

    func delete(relativePath: String?) {
        guard let relativePath,
              let url = fileURL(relativePath: relativePath) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    func duration(for relativePath: String) async -> Double {
        guard let url = fileURL(relativePath: relativePath) else { return 0 }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        return max(0, duration.seconds)
    }

    func deleteOrphans(keeping relativePaths: Set<String>) throws {
        for kind in [MediaKind.audio, .video] {
            let directory = try mediaDirectory(for: kind)
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            for file in files {
                let relativePath = "\(rootFolder)/\(kind.rawValue)/\(file.lastPathComponent)"
                if !relativePaths.contains(relativePath) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    private func mediaDirectory(for kind: MediaKind) throws -> URL {
        let directory = try baseDirectory()
            .appending(path: rootFolder, directoryHint: .isDirectory)
            .appending(path: kind.rawValue, directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    private func baseDirectory() throws -> URL {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw StorageError.couldNotCreateDirectory
        }
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    private func defaultExtension(for kind: MediaKind) -> String {
        switch kind {
        case .audio: "m4a"
        case .video: "mov"
        }
    }
}
