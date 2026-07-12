import SwiftData
import SwiftUI
import UIKit
import PhotosUI

struct LookbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \LookbookEntry.createdAt, order: .reverse) private var entries: [LookbookEntry]
    @Query(sort: \LookbookBoard.sortIndex) private var customBoards: [LookbookBoard]

    @State private var showsCreateBoard = false
    @State private var newBoardName = ""
    @State private var boardNameBeingRenamed: String?
    @State private var renamedBoardName = ""
    @State private var searchText = ""
    @State private var libraryFilter: LibraryFilter = .all
    @State private var selectedSection: InspirationSection = .all
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedComposer: InspirationComposerKind?
    @State private var importError: String?
    @State private var showsProfile = false
    @State private var showsAudioRecorder = false

    private let imageStorage = ImageStorageService()
    private let mediaStorage = InspirationMediaStorageService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionPicker

                    if isSearchingOrFiltering {
                        referenceResults
                    } else {
                        switch selectedSection {
                        case .all:
                            inspirationHeader
                            referenceResults
                        case .collections:
                            collectionHeader
                            boardGrid
                        }
                    }
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
            .navigationTitle("灵感")
            .searchable(text: $searchText, prompt: "搜索灵感、情绪、地点或标签")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("个人资料与设置", systemImage: "person.crop.circle") {
                        showsProfile = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("查看本地创作空间和取景设置")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if selectedSection == .all {
                        Menu("筛选", systemImage: "line.3.horizontal.decrease.circle") {
                            Picker("筛选", selection: $libraryFilter) {
                                ForEach(LibraryFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("筛选灵感")
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("添加照片灵感", systemImage: "photo.badge.plus")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("从照片图库添加一条灵感")

                    Menu("添加灵感", systemImage: "plus") {
                        Button("文字", systemImage: "text.quote") {
                            selectedComposer = .text
                        }
                        Button("记录声音", systemImage: "waveform") {
                            showsAudioRecorder = true
                        }
                        Button("音乐", systemImage: "music.note") {
                            selectedComposer = .music
                        }
                        PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                            Label("视频", systemImage: "video")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("添加文字、声音、音乐或视频")
                }
            }
            .sheet(isPresented: $showsCreateBoard) {
                createBoardSheet
            }
            .sheet(isPresented: renameSheetBinding) {
                renameBoardSheet
            }
            .sheet(isPresented: $showsProfile) {
                ProfileView()
            }
            .sheet(item: $selectedComposer) { kind in
                InspirationComposerSheet(kind: kind, onSave: saveComposedInspiration)
            }
            .sheet(isPresented: $showsAudioRecorder) {
                AudioRecorderSheet(onSave: saveAudioInspiration)
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    await importPhoto(from: item)
                }
            }
            .onChange(of: selectedVideoItem) { _, item in
                Task {
                    await importVideo(from: item)
                }
            }
            .task {
                do {
                    try InspirationMigrationService().migrateLegacyImages(in: modelContext)
                    try InspirationFileMaintenanceService().removeOrphanedFiles(in: modelContext)
                } catch {
                    importError = "旧灵感仍可查看，但媒体维护失败：\(error.localizedDescription)"
                }
            }
            .alert("无法导入照片", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("关闭", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var boardColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 260), spacing: 16)]
    }

    private var isSearchingOrFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || libraryFilter != .all
    }

    private var sectionPicker: some View {
        Picker("灵感视图", selection: $selectedSection) {
            ForEach(InspirationSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedSection) { _, section in
            if section == .collections {
                libraryFilter = .all
            }
        }
    }

    private var boardGrid: some View {
        LazyVGrid(columns: boardColumns, spacing: 14) {
            ForEach(boardSummaries) { summary in
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        BoardDetailView(
                            summary: summary,
                            entries: entries(for: summary),
                            boardNames: movableBoardNames
                        )
                    } label: {
                        BoardCard(summary: summary)
                    }
                    .buttonStyle(.plain)

                    if !summary.isSystemBoard {
                        Menu("更多操作", systemImage: "ellipsis.circle") {
                            Button("重命名") {
                                boardNameBeingRenamed = summary.name
                                renamedBoardName = summary.name
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("\(summary.displayName)更多操作")
                        .padding(8)
                    }
                }
            }

            Button(action: prepareNewBoard) {
                CreateBoardCard()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var referenceResults: some View {
        if entries.isEmpty && !isSearchingOrFiltering {
            ContentUnavailableView {
                Label("记录第一个灵感", systemImage: "sparkles")
            } description: {
                Text("可以从一句话、一张照片、一段声音或现场取景开始。")
            } actions: {
                Button("记录文字", systemImage: "text.quote") {
                    selectedComposer = .text
                }
                .buttonStyle(.borderedProminent)
                .tint(SceneZeroTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 56)
        } else if filteredEntries.isEmpty {
            ContentUnavailableView(
                "没有找到灵感",
                systemImage: "magnifyingglass",
                description: Text("尝试其他关键词，或清除当前筛选。")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
        } else {
            WaterfallLayout(maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 3) {
                ForEach(filteredEntries) { entry in
                    NavigationLink {
                        LookbookDetailView(entry: entry, boardNames: movableBoardNames)
                    } label: {
                        InspirationCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var inspirationHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("所有灵感")
                .font(.title2.bold())

            Text("记录现实中的构图、光影和情绪；需要时再用 AR 与提示词继续发展。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("\(entries.count) 条记录 · 默认保存在此设备", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(SceneZeroTheme.accent)
        }
    }

    private var collectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("灵感集")
                    .font(.title2.bold())
                Text("围绕一个故事、情感状态或表达欲望慢慢收集。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("新建", systemImage: "plus", action: prepareNewBoard)
                .labelStyle(.iconOnly)
                .accessibilityLabel("新建灵感集")
        }
    }

    private var boardSummaries: [LookbookBoardSummary] {
        let builtIns = [
            LookbookBoardSummary(
                name: LookbookBoard.favoritesBoardName,
                systemImage: "heart",
                count: favoriteEntries.count,
                isSystemBoard: true,
                coverPaths: Array(favoriteEntries.lazy.map(\.imagePath).filter { !$0.isEmpty }.prefix(4))
            )
        ]

        let custom = customBoards.map { board in
            let boardEntries = sortedEntries(entries.filter { $0.boardName == board.name })
            return LookbookBoardSummary(
                name: board.name,
                systemImage: "square.grid.2x2",
                count: boardEntries.count,
                isSystemBoard: false,
                coverPaths: Array(boardEntries.lazy.map(\.imagePath).filter { !$0.isEmpty }.prefix(4))
            )
        }

        return builtIns + custom
    }

    private var favoriteEntries: [LookbookEntry] {
        entries.filter(\.isFavorite)
    }

    private var filteredEntries: [LookbookEntry] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let matchesFilter: Bool
            switch libraryFilter {
            case .all:
                matchesFilter = true
            case .favorites:
                matchesFilter = entry.isFavorite
            case .untagged:
                matchesFilter = entry.tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            guard matchesFilter, !searchTerm.isEmpty else { return matchesFilter }
            let searchableText = [entry.title, entry.note, entry.prompt, entry.tagsText, entry.locationName]
                .joined(separator: " ")
            return searchableText.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    private var movableBoardNames: [String] {
        [LookbookBoard.defaultBoardName] + customBoards.map(\.name)
    }

    private var createBoardSheet: some View {
        NavigationStack {
            Form {
                Section("灵感集") {
                    TextField("名称", text: $newBoardName)
                }
            }
            .navigationTitle("新建灵感集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showsCreateBoard = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createBoard()
                    }
                    .disabled(trimmedBoardName.isEmpty || boardNameExists(trimmedBoardName))
                }
            }
        }
    }

    private var renameBoardSheet: some View {
        NavigationStack {
            Form {
                Section("灵感集") {
                    TextField("名称", text: $renamedBoardName)
                }
            }
            .navigationTitle("重命名灵感集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        boardNameBeingRenamed = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        renameBoard()
                    }
                    .disabled(!canRenameBoard)
                }
            }
        }
    }

    private var renameSheetBinding: Binding<Bool> {
        Binding(
            get: { boardNameBeingRenamed != nil },
            set: { if !$0 { boardNameBeingRenamed = nil } }
        )
    }

    private var trimmedBoardName: String {
        newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func entries(for summary: LookbookBoardSummary) -> [LookbookEntry] {
        switch summary.name {
        case LookbookBoard.defaultBoardName:
            entries
        case LookbookBoard.favoritesBoardName:
            favoriteEntries
        default:
            sortedEntries(entries.filter { $0.boardName == summary.name })
        }
    }

    private func sortedEntries(_ entries: [LookbookEntry]) -> [LookbookEntry] {
        entries.sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    private func createBoard() {
        let board = LookbookBoard(
            name: trimmedBoardName,
            sortIndex: customBoards.count + 1
        )
        modelContext.insert(board)
        try? modelContext.save()
        showsCreateBoard = false
    }

    private func prepareNewBoard() {
        newBoardName = ""
        showsCreateBoard = true
    }

    private func boardNameExists(_ name: String) -> Bool {
        movableBoardNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
            || name.caseInsensitiveCompare(LookbookBoard.favoritesBoardName) == .orderedSame
    }

    private var canRenameBoard: Bool {
        let candidate = renamedBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              let currentName = boardNameBeingRenamed,
              candidate.caseInsensitiveCompare(currentName) != .orderedSame else {
            return false
        }

        return !boardNameExists(candidate)
    }

    private func renameBoard() {
        guard let currentName = boardNameBeingRenamed else {
            return
        }

        let newName = renamedBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let board = customBoards.first(where: { $0.name == currentName }) else {
            boardNameBeingRenamed = nil
            return
        }

        board.name = newName
        board.updatedAt = Date()
        entries
            .filter { $0.boardName == currentName }
            .forEach { $0.boardName = newName }
        try? modelContext.save()
        boardNameBeingRenamed = nil
    }

    @MainActor
    private func importPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedPhotoItem = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                importError = "无法读取这张照片。请尝试选择其他图片。"
                return
            }

            let imagePath = try imageStorage.save(image)
            let entry = LookbookEntry(
                title: "照片灵感 \(Date().formatted(date: .numeric, time: .shortened))",
                imagePath: imagePath,
                prompt: "",
                shotType: ShotType.wide.rawValue,
                lightPreset: "未标注",
                colorTemperature: "未标注",
                filterName: FilterPreset.realistic.rawValue,
                layoutJSON: "[]",
                locationName: "照片图库"
            )
            let asset = InspirationAsset(
                kind: .image,
                relativePath: imagePath,
                title: entry.title,
                pixelWidth: image.size.width,
                pixelHeight: image.size.height,
                entry: entry
            )
            modelContext.insert(entry)
            modelContext.insert(asset)
            entry.assets.append(asset)
            do {
                try modelContext.save()
            } catch {
                imageStorage.delete(relativePath: imagePath)
                throw error
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func importVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedVideoItem = nil }

        var storedPath: String?
        do {
            guard let importedFile = try await item.loadTransferable(type: ImportedMediaFile.self) else {
                throw InspirationMediaStorageService.StorageError.unsupportedFile
            }
            defer { try? FileManager.default.removeItem(at: importedFile.url) }

            let path = try mediaStorage.importFile(at: importedFile.url, kind: .video)
            storedPath = path
            let duration = await mediaStorage.duration(for: path)
            let entry = makeEntry(title: "视频灵感", locationName: "照片图库")
            let asset = InspirationAsset(
                kind: .video,
                relativePath: path,
                title: entry.title,
                duration: duration,
                entry: entry
            )
            modelContext.insert(entry)
            modelContext.insert(asset)
            entry.assets.append(asset)
            try modelContext.save()
        } catch {
            mediaStorage.delete(relativePath: storedPath)
            importError = error.localizedDescription
        }
    }

    private func saveComposedInspiration(
        title: String,
        content: String,
        subtitle: String,
        url: URL?
    ) {
        let kind = selectedComposer ?? .text
        let assetKind: InspirationAssetKind = kind == .music ? .music : .text
        let resolvedTitle = title.isEmpty
            ? (kind == .music ? "音乐灵感" : String(content.prefix(24)))
            : title
        let entry = makeEntry(title: resolvedTitle, note: content)
        let asset = InspirationAsset(
            kind: assetKind,
            textContent: content,
            externalURLString: url?.absoluteString,
            title: resolvedTitle,
            subtitle: subtitle,
            entry: entry
        )
        modelContext.insert(entry)
        modelContext.insert(asset)
        entry.assets.append(asset)
        do {
            try modelContext.save()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func saveAudioInspiration(
        temporaryURL: URL,
        duration: Double,
        title: String,
        note: String
    ) throws {
        let path = try mediaStorage.commitRecordedAudio(at: temporaryURL)
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "声音灵感"
            : title
        let entry = makeEntry(title: resolvedTitle, note: note, locationName: "现场录音")
        let asset = InspirationAsset(
            kind: .audio,
            textContent: note,
            relativePath: path,
            title: resolvedTitle,
            duration: duration,
            entry: entry
        )
        modelContext.insert(entry)
        modelContext.insert(asset)
        entry.assets.append(asset)
        do {
            try modelContext.save()
        } catch {
            mediaStorage.delete(relativePath: path)
            throw error
        }
    }

    private func makeEntry(
        title: String,
        note: String = "",
        locationName: String = "灵感记录"
    ) -> LookbookEntry {
        LookbookEntry(
            title: title,
            imagePath: "",
            prompt: "",
            shotType: ShotType.wide.rawValue,
            lightPreset: "未标注",
            colorTemperature: "未标注",
            filterName: FilterPreset.realistic.rawValue,
            layoutJSON: "[]",
            note: note,
            locationName: locationName
        )
    }
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case untagged

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "全部"
        case .favorites: "收藏"
        case .untagged: "未添加标签"
        }
    }
}

private enum InspirationSection: String, CaseIterable, Identifiable {
    case all
    case collections

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "所有灵感"
        case .collections: "灵感集"
        }
    }
}

private struct LookbookBoardSummary: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let systemImage: String
    let count: Int
    let isSystemBoard: Bool
    let coverPaths: [String]

    var displayName: String {
        LookbookBoard.displayName(for: name)
    }

}

private struct BoardCard: View {
    let summary: LookbookBoardSummary
    private let imageStorage = ImageStorageService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover
                .aspectRatio(1.36, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(summary.count) 条灵感")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .groupedCard(cornerRadius: 18)
    }

    private var cover: some View {
        GeometryReader { proxy in
            if summary.coverPaths.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.quaternary)
                    Image(systemName: summary.systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                collage(size: proxy.size)
            }
        }
    }

    private func collage(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(summary.coverPaths.prefix(4).enumerated()), id: \.offset) { index, path in
                if let image = imageStorage.load(relativePath: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: tileFrame(for: index, in: size).width,
                            height: tileFrame(for: index, in: size).height
                        )
                        .clipped()
                        .position(tileCenter(for: index, in: size))
                }
            }
        }
        .background(.quaternary)
    }

    private func tileFrame(for index: Int, in size: CGSize) -> CGSize {
        if summary.coverPaths.count == 1 {
            return size
        }
        if index == 0 {
            return CGSize(width: size.width * 0.62, height: size.height)
        }
        return CGSize(width: size.width * 0.38, height: size.height / 3)
    }

    private func tileCenter(for index: Int, in size: CGSize) -> CGPoint {
        if summary.coverPaths.count == 1 {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        if index == 0 {
            return CGPoint(x: size.width * 0.31, y: size.height / 2)
        }
        return CGPoint(
            x: size.width * 0.81,
            y: size.height * (CGFloat(index) - 0.5) / 3
        )
    }
}

private struct CreateBoardCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.quaternary)

                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                    Text("新建灵感集")
                        .font(.headline)
                    Text("为一个新故事慢慢收集")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .foregroundStyle(.primary)
            }
            .aspectRatio(1.36, contentMode: .fit)

            VStack(alignment: .leading, spacing: 3) {
                Text("新建灵感集")
                    .font(.headline)
                    .lineLimit(1)

                Text("创建一个新的故事集合")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .groupedCard(cornerRadius: 20)
        .accessibilityLabel("新建灵感集")
    }
}

private struct BoardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: LookbookBoardSummary
    let entries: [LookbookEntry]
    let boardNames: [String]

    @State private var isArranging = false
    @State private var arrangedEntries: [LookbookEntry] = []

    var body: some View {
        Group {
            if isArranging {
                arrangeList
                    .background(SceneZeroTheme.background)
            } else {
                ScrollView {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "这个灵感集还是空的",
                            systemImage: summary.systemImage,
                            description: Text("从所有灵感中选择内容，或去现场记录新的构图与光影。")
                        )
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                    } else {
                        WaterfallLayout(
                            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 3
                        ) {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    LookbookDetailView(entry: entry, boardNames: boardNames)
                                } label: {
                                    InspirationCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
                .background(SceneZeroTheme.background)
            }
        }
        .navigationTitle(summary.displayName)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            arrangedEntries = entries
        }
        .onChange(of: entries.map(\.id)) { _, _ in
            if !isArranging {
                arrangedEntries = entries
            }
        }
        .environment(\.editMode, .constant(isArranging ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LookbookBackButton {
                    dismiss()
                }
            }

            if canArrange {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isArranging ? "完成" : "排序") {
                        toggleArrangeMode()
                    }
                    .disabled(entries.isEmpty)
                }
            }
        }
    }

    private var arrangeList: some View {
        List {
            Section {
                ForEach(arrangedEntries) { entry in
                    HStack(spacing: 12) {
                        ReferenceThumbnail(entry: entry)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveEntries)
            } footer: {
                Text("拖动内容，调整它们在这个灵感集中的浏览顺序。")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var canArrange: Bool {
        !summary.isSystemBoard
    }

    private func toggleArrangeMode() {
        if isArranging {
            saveArrangement()
        } else {
            arrangedEntries = entries
        }

        withAnimation(.snappy(duration: 0.2)) {
            isArranging.toggle()
        }
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        arrangedEntries.move(fromOffsets: source, toOffset: destination)
    }

    private func saveArrangement() {
        for (index, entry) in arrangedEntries.enumerated() {
            entry.sortIndex = index
        }
        try? modelContext.save()
    }

}

private struct ReferenceThumbnail: View {
    let entry: LookbookEntry
    private let imageStorage = ImageStorageService()

    var body: some View {
        Group {
            if let image = imageStorage.load(relativePath: entry.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: 72, height: 54)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LookbookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showsCopyConfirmation = false
    @State private var showsPromptFields = false
    @State private var promptPlatform: VideoPromptPlatform = .generic
    @State private var editableNote: String
    @State private var editableTags: String
    @State private var editableLocation: String
    @State private var showsDeleteConfirmation = false

    let entry: LookbookEntry
    var boardNames: [String] = [LookbookBoard.defaultBoardName]

    private let imageStorage = ImageStorageService()
    private let mediaStorage = InspirationMediaStorageService()

    init(entry: LookbookEntry, boardNames: [String] = [LookbookBoard.defaultBoardName]) {
        self.entry = entry
        self.boardNames = boardNames
        _editableNote = State(initialValue: entry.note)
        _editableTags = State(initialValue: entry.tagsText)
        _editableLocation = State(initialValue: entry.locationName)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    referenceSummaryCard(availableWidth: proxy.size.width)

                    if shouldShowAssetGallery {
                        assetGallery
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("我当时想到", systemImage: "pencil")
                            .font(.headline)
                        TextEditor(text: $editableNote)
                            .frame(minHeight: 108)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(SceneZeroTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                if editableNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("记录这个场景触发的故事、情绪或未来用途。")
                                        .font(.body)
                                        .foregroundStyle(.secondary.opacity(0.72))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(14)
                    .groupedCard(cornerRadius: 20)

                    if entry.inspirationKind == .image || !entry.prompt.isEmpty {
                        structuredPromptCard
                    }
                    organizationCard
                    metadataCard
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
        }
        .navigationTitle("灵感详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: editableNote) { _, newValue in
            entry.note = newValue
            if entry.inspirationKind == .image {
                entry.prompt = PromptService.structuredPrompt(from: entry).fullText
            }
            try? modelContext.save()
        }
        .onChange(of: editableTags) { _, newValue in
            entry.tagsText = newValue
            try? modelContext.save()
        }
        .onChange(of: editableLocation) { _, newValue in
            entry.locationName = newValue
            try? modelContext.save()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LookbookBackButton {
                    dismiss()
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    entry.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(entry.isFavorite ? "取消收藏灵感" : "收藏灵感")

                Menu("选择灵感集", systemImage: "rectangle.stack.badge.plus") {
                    ForEach(boardNames, id: \.self) { boardName in
                        Button {
                            entry.boardName = boardName
                            try? modelContext.save()
                        } label: {
                            if entry.boardName == boardName {
                                Label(LookbookBoard.displayName(for: boardName), systemImage: "checkmark")
                            } else {
                                Text(LookbookBoard.displayName(for: boardName))
                            }
                        }
                    }
                }
                .labelStyle(.iconOnly)
                .accessibilityHint("选择这条灵感当前所在的灵感集")

                Menu("更多", systemImage: "ellipsis.circle") {
                    Button("删除灵感", systemImage: "trash", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                }
                .labelStyle(.iconOnly)
                .confirmationDialog(
                    "删除这条灵感？",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("删除灵感", role: .destructive, action: deleteEntry)
                    Button("取消", role: .cancel) { }
                } message: {
                    Text("文字和媒体文件将从此设备删除，此操作无法撤销。")
                }
            }
        }
    }

    private var shouldShowAssetGallery: Bool {
        entry.inspirationKind != .image || entry.orderedAssets.count > 1
    }

    private var assetGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(entry.orderedAssets) { asset in
                InspirationAssetView(asset: asset)
            }
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private func referenceSummaryCard(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                if let image = imageStorage.load(relativePath: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: min(112, availableWidth * 0.30), height: 86)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: entry.inspirationKind.systemImage)
                        .font(.title)
                        .foregroundStyle(SceneZeroTheme.accent)
                        .frame(width: min(112, availableWidth * 0.30), height: 86)
                        .background(SceneZeroTheme.accentSoft, in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text("\(entry.inspirationKind.displayName) · \(entry.createdAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(entry.frameAspectRatio) · \(entry.lensPreset) · \(displayShotName)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SceneZeroTheme.infoAccent)
                }
            }

            Text("位于 \(LookbookBoard.displayName(for: entry.boardName))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SceneZeroTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SceneZeroTheme.accentSoft, in: Capsule())
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var structuredPromptCard: some View {
        let structuredPrompt = PromptService.structuredPrompt(from: entry)
        return VStack(alignment: .leading, spacing: 12) {
            Label("结构化提示词", systemImage: "sparkle")
                .font(.headline)
                .foregroundStyle(SceneZeroTheme.promptAccent)

            Text(structuredPrompt.base)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("查看全部字段", isExpanded: $showsPromptFields) {
                VStack(alignment: .leading, spacing: 12) {
                    StructuredPromptSection(title: "氛围补充", text: structuredPrompt.atmosphere)
                    StructuredPromptSection(title: "镜头与空间", text: structuredPrompt.shotMetadata)
                    StructuredPromptSection(title: "保留元素", text: structuredPrompt.keepElements)
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.semibold))

            Picker("导出格式", selection: $promptPlatform) {
                ForEach(VideoPromptPlatform.allCases) { platform in
                    Text(platform.displayName).tag(platform)
                }
            }
            .pickerStyle(.menu)

            Text("复制时会按 \(promptPlatform.displayName) 的字段顺序组织提示词。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Button {
                    copyPrompt()
                } label: {
                    Label("复制提示词", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(SceneZeroTheme.accent, in: Capsule())
                .accessibilityLabel("复制结构化提示词")

                if let imageURL = imageStorage.fileURL(relativePath: entry.imagePath) {
                    ShareLink(item: imageURL) {
                        Label("导出参考图", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SceneZeroTheme.infoAccent)
                    .background(SceneZeroTheme.infoAccentSoft.opacity(0.84), in: Capsule())
                    .accessibilityLabel("导出参考图")
                }

                if showsCopyConfirmation {
                    Label("提示词已复制", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var organizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("地点与标签", systemImage: "tag")
                .font(.headline)

            TextField("地点或空间", text: $editableLocation)
                .textFieldStyle(.roundedBorder)

            TextField("标签，用逗号分隔", text: $editableTags)
                .textFieldStyle(.roundedBorder)

            Text("例如：黄昏、低机位、疏离。标签可用于灵感搜索。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private var displayShotName: String {
        ShotType(rawValue: entry.shotType)?.displayName ?? entry.shotType
    }

    private var metadataCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            metadataRow("灵感集", LookbookBoard.displayName(for: entry.boardName))
            metadataRow("类型", entry.inspirationKind.displayName)
            metadataRow("记录时间", entry.createdAt.formatted(date: .abbreviated, time: .shortened))

            if entry.inspirationKind == .image {
                let lightRecords = lightRecords(for: entry)
                metadataRow("景别", displayShotName)
                metadataRow("画幅", entry.frameAspectRatio)
                metadataRow("镜头", entry.lensPreset)
                metadataRow("构图线", entry.showsCompositionGuides ? "开启" : "关闭")
                metadataRow("灯光", entry.lightPreset)
                if lightRecords.count == 1, let light = lightRecords.first {
                    metadataRow("色温", light.colorTemperature?.displayName ?? entry.colorTemperature)
                    metadataRow("强度", "\(Int((light.lightIntensity ?? entry.lightIntensity) * 100))%")
                    metadataRow("范围", "\(Int((light.lightRadius ?? entry.lightRadius) * 100))%")
                } else if lightRecords.count > 1 {
                    metadataRow("灯位细节", "已保存 \(lightRecords.count) 个灯位")
                }
                metadataRow("色彩风格", FilterPreset(rawValue: entry.filterName)?.displayName ?? entry.filterName)
            }
        }
        .font(.subheadline)
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func lightRecords(for entry: LookbookEntry) -> [SceneObjectRecord] {
        PromptService.lightRecords(from: PromptService.layoutRecords(from: entry))
    }

    private func copyPrompt() {
        UIPasteboard.general.string = PromptService.adaptedPrompt(from: entry, for: promptPlatform)

        withAnimation(.easeOut(duration: 0.18)) {
            showsCopyConfirmation = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeIn(duration: 0.18)) {
                showsCopyConfirmation = false
            }
        }
    }

    private func deleteEntry() {
        for asset in entry.assets {
            switch asset.kind {
            case .image:
                imageStorage.delete(relativePath: asset.relativePath ?? "")
            case .audio, .video:
                mediaStorage.delete(relativePath: asset.relativePath)
                if let thumbnailPath = asset.thumbnailPath {
                    imageStorage.delete(relativePath: thumbnailPath)
                }
            case .text, .music:
                break
            }
        }

        if entry.assets.isEmpty && !entry.imagePath.isEmpty {
            imageStorage.delete(relativePath: entry.imagePath)
        }

        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}

private struct StructuredPromptSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct DetailImageView: View {
    let image: UIImage
    let availableWidth: CGFloat

    var body: some View {
        let width = displayWidth
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var displayWidth: CGFloat {
        let pixelWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let nativePointWidth = pixelWidth / max(UIScreen.main.scale, 1)
        return min(max(1, availableWidth), max(1, nativePointWidth))
    }
}

private struct LookbookBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
    }
}

#Preview {
    LookbookView()
        .modelContainer(for: [LookbookEntry.self, InspirationAsset.self, LookbookBoard.self, SceneProject.self], inMemory: true)
}
