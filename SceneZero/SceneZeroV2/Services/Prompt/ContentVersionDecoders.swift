import Foundation

enum ContentDecodingError: LocalizedError, Equatable {
    case missingVersion(contentType: String)
    case malformed(contentType: String)
    case unsupportedVersion(contentType: String, version: Int)
    case inconsistentDocumentVersion(documentVersion: Int, blobVersion: Int)

    var errorDescription: String? {
        switch self {
        case .missingVersion(let contentType): "\(contentType)缺少内容版本。"
        case .malformed(let contentType): "\(contentType)数据已损坏。"
        case .unsupportedVersion(let contentType, let version): "\(contentType)版本 \(version) 暂不受当前 App 支持。"
        case .inconsistentDocumentVersion(let documentVersion, let blobVersion):
            "提示词文档版本 \(documentVersion) 与内容版本 \(blobVersion) 不一致。"
        }
    }
}

enum SceneSnapshotDecoder {
    static func decode(_ data: Data) throws -> SceneSnapshot {
        let version = try schemaVersion(in: data, contentType: "场景快照")
        guard version == SceneSnapshot.currentSchemaVersion else {
            throw ContentDecodingError.unsupportedVersion(contentType: "场景快照", version: version)
        }
        do {
            return try JSONDecoder().decode(SceneSnapshot.self, from: data)
        } catch {
            throw ContentDecodingError.malformed(contentType: "场景快照")
        }
    }
}

enum PromptDraftDecoder {
    static func decode(_ data: Data, documentVersion: Int? = nil) throws -> PromptDraft {
        let version = try schemaVersion(in: data, contentType: "结构化提示词")
        if let documentVersion, documentVersion != version {
            throw ContentDecodingError.inconsistentDocumentVersion(
                documentVersion: documentVersion,
                blobVersion: version
            )
        }
        guard version == PromptDraft.currentSchemaVersion else {
            throw ContentDecodingError.unsupportedVersion(contentType: "结构化提示词", version: version)
        }
        do {
            return try JSONDecoder().decode(PromptDraft.self, from: data)
        } catch {
            throw ContentDecodingError.malformed(contentType: "结构化提示词")
        }
    }
}

private func schemaVersion(in data: Data, contentType: String) throws -> Int {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ContentDecodingError.malformed(contentType: contentType)
    }
    guard let version = object["schemaVersion"] as? Int else {
        throw ContentDecodingError.missingVersion(contentType: contentType)
    }
    return version
}
