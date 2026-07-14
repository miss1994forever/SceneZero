import Foundation
import SwiftData

@MainActor
struct InspirationCollectionService {
    static let backfillMarkerKey = "SceneZeroV2.collectionMembershipBackfill.v1"

    struct BackfillReport: Equatable {
        var scanned = 0
        var created = 0
        var skipped = 0
        var conflicts = 0
    }

    func collections(containing inspiration: Inspiration) -> [InspirationCollection] {
        inspiration.memberships
            .compactMap(\.collection)
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    func entries(in collection: InspirationCollection) -> [Inspiration] {
        collection.memberships
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.addedAt < rhs.addedAt
                }
                return lhs.sortIndex < rhs.sortIndex
            }
            .compactMap(\.inspiration)
    }

    func contains(_ inspiration: Inspiration, in collection: InspirationCollection) -> Bool {
        inspiration.memberships.contains { $0.collection?.id == collection.id }
    }

    func assign(_ inspiration: Inspiration, toCollectionNamed name: String, in context: ModelContext) throws {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // “所有灵感”是一个查询结果，而不是持久化 membership。
        guard !resolvedName.isEmpty,
              resolvedName != InspirationCollection.defaultBoardName,
              resolvedName != InspirationCollection.favoritesBoardName else {
            return
        }
        try add(inspiration, to: collection(named: resolvedName, in: context), in: context)
    }

    func add(_ inspiration: Inspiration, to collection: InspirationCollection, in context: ModelContext) throws {
        guard !contains(inspiration, in: collection) else { return }
        let nextSortIndex = (collection.memberships.map(\.sortIndex).max() ?? -1) + 1
        let membership = CollectionMembership(
            inspiration: inspiration,
            collection: collection,
            sortIndex: nextSortIndex
        )
        context.insert(membership)
        inspiration.memberships.append(membership)
        collection.memberships.append(membership)
        inspiration.updatedAt = .now
        collection.updatedAt = .now
    }

    func remove(_ inspiration: Inspiration, from collection: InspirationCollection, in context: ModelContext) {
        guard let membership = inspiration.memberships.first(where: { $0.collection?.id == collection.id }) else {
            return
        }
        context.delete(membership)
        inspiration.updatedAt = .now
        collection.updatedAt = .now
    }

    func replaceMemberships(
        for inspiration: Inspiration,
        with collections: [InspirationCollection],
        in context: ModelContext
    ) throws {
        let requestedIDs = Set(collections.map(\.id))
        for membership in inspiration.memberships where !requestedIDs.contains(membership.collection?.id ?? UUID()) {
            context.delete(membership)
        }
        for collection in collections where !contains(inspiration, in: collection) {
            try add(inspiration, to: collection, in: context)
        }
        inspiration.updatedAt = .now
    }

    func reorder(_ inspirations: [Inspiration], in collection: InspirationCollection) {
        let membershipsByInspirationID = Dictionary(
            uniqueKeysWithValues: collection.memberships.compactMap { membership in
                membership.inspiration.map { ($0.id, membership) }
            }
        )
        for (index, inspiration) in inspirations.enumerated() {
            membershipsByInspirationID[inspiration.id]?.sortIndex = index
        }
        collection.updatedAt = .now
    }

    func rename(_ collection: InspirationCollection, to name: String) throws {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedName.isEmpty else {
            throw CollectionError.emptyName
        }
        guard resolvedName != InspirationCollection.defaultBoardName,
              resolvedName != InspirationCollection.favoritesBoardName else {
            throw CollectionError.reservedName
        }
        collection.name = resolvedName
        collection.updatedAt = .now
    }

    func deleteCollection(_ collection: InspirationCollection, keepingInspirations: Bool = true, in context: ModelContext) {
        guard keepingInspirations else { return }
        context.delete(collection)
    }

    func backfillLegacyMemberships(in context: ModelContext) throws -> BackfillReport {
        guard !UserDefaults.standard.bool(forKey: Self.backfillMarkerKey) else {
            return .init()
        }

        let entries = try context.fetch(FetchDescriptor<Inspiration>())
        var report = BackfillReport()
        for inspiration in entries {
            let legacyName = inspiration.boardName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !legacyName.isEmpty,
                  legacyName != InspirationCollection.defaultBoardName,
                  legacyName != InspirationCollection.favoritesBoardName else {
                continue
            }
            report.scanned += 1
            let collection = try collection(named: legacyName, in: context)
            if contains(inspiration, in: collection) {
                report.skipped += 1
                continue
            }
            let membership = CollectionMembership(
                inspiration: inspiration,
                collection: collection,
                sortIndex: inspiration.sortIndex
            )
            context.insert(membership)
            inspiration.memberships.append(membership)
            collection.memberships.append(membership)
            report.created += 1
        }
        try context.save()
        UserDefaults.standard.set(true, forKey: Self.backfillMarkerKey)
        return report
    }

    private func collection(named name: String, in context: ModelContext) throws -> InspirationCollection {
        let descriptor = FetchDescriptor<InspirationCollection>(
            predicate: #Predicate { $0.name == name }
        )
        if let collection = try context.fetch(descriptor).first {
            return collection
        }
        let collection = InspirationCollection(name: name)
        context.insert(collection)
        return collection
    }
}

enum CollectionError: LocalizedError {
    case emptyName
    case reservedName

    var errorDescription: String? {
        switch self {
        case .emptyName: "灵感集名称不能为空。"
        case .reservedName: "这个名称由系统保留，不能用作灵感集。"
        }
    }
}
