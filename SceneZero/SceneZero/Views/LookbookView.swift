import SwiftData
import SwiftUI
import UIKit

struct LookbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LookbookEntry.createdAt, order: .reverse) private var entries: [LookbookEntry]
    @Query(sort: \LookbookBoard.sortIndex) private var customBoards: [LookbookBoard]

    @State private var showsCreateBoard = false
    @State private var newBoardName = ""
    @State private var boardNameBeingRenamed: String?
    @State private var renamedBoardName = ""

    private let imageStorage = ImageStorageService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    libraryHeader

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
                                    Menu {
                                        Button("重命名") {
                                            boardNameBeingRenamed = summary.name
                                            renamedBoardName = summary.name
                                        }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 36, height: 36)
                                        .liquidGlassCircle()
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("灵感集更多操作")
                                .padding(8)
                            }
                        }
                        }

                        Button {
                            newBoardName = ""
                            showsCreateBoard = true
                        } label: {
                            CreateBoardCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
            .navigationTitle("灵感库")
            .sheet(isPresented: $showsCreateBoard) {
                createBoardSheet
            }
            .sheet(isPresented: renameSheetBinding) {
                renameBoardSheet
            }
        }
    }

    private var boardColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 260), spacing: 16)]
    }

    private var libraryHeader: some View {
        HStack(spacing: 10) {
            Label("默认私密 · 本地保存", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SceneZeroTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(SceneZeroTheme.accentSoft, in: Capsule())

            Text("\(entries.count) 个参考包")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 8)
    }

    private var boardSummaries: [LookbookBoardSummary] {
        let builtIns = [
            LookbookBoardSummary(
                name: LookbookBoard.defaultBoardName,
                systemImage: "rectangle.stack",
                count: entries.count,
                isSystemBoard: true,
                coverPaths: Array(entries.prefix(4).map(\.imagePath))
            ),
            LookbookBoardSummary(
                name: LookbookBoard.favoritesBoardName,
                systemImage: "heart",
                count: favoriteEntries.count,
                isSystemBoard: true,
                coverPaths: Array(favoriteEntries.prefix(4).map(\.imagePath))
            )
        ]

        let custom = customBoards.map { board in
            let boardEntries = sortedEntries(entries.filter { $0.boardName == board.name })
            return LookbookBoardSummary(
                name: board.name,
                systemImage: "square.grid.2x2",
                count: boardEntries.count,
                isSystemBoard: false,
                coverPaths: Array(boardEntries.prefix(4).map(\.imagePath))
            )
        }

        return builtIns + custom
    }

    private var favoriteEntries: [LookbookEntry] {
        entries.filter(\.isFavorite)
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

    var statusTag: String {
        if name == LookbookBoard.defaultBoardName {
            return "最近更新"
        }
        if name == LookbookBoard.favoritesBoardName {
            return "收藏"
        }
        return count > 0 ? "已整理" : "待整理"
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

                Text("\(summary.count) 个场景 · \(summary.count) 个参考包")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(summary.statusTag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SceneZeroTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SceneZeroTheme.accentSoft, in: Capsule())
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

    let summary: LookbookBoardSummary
    let entries: [LookbookEntry]
    let boardNames: [String]

    @State private var isArranging = false
    @State private var arrangedEntries: [LookbookEntry] = []

    var body: some View {
        GeometryReader { proxy in
            let metrics = gridMetrics(for: proxy.size.width)

            if isArranging {
                arrangeList
                    .background(SceneZeroTheme.background)
            } else {
                ScrollView {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "暂无参考图",
                            systemImage: summary.systemImage,
                            description: Text("去现场取景，或把参考图移动到这个灵感集。")
                        )
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: metrics.columns, spacing: metrics.spacing) {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    LookbookDetailView(entry: entry, boardNames: boardNames)
                                } label: {
                                    ReferenceTile(entry: entry, tileWidth: metrics.tileWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
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
                Text("拖动参考图，整理这个灵感集里的场景顺序。")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func gridMetrics(for width: CGFloat) -> BoardGridMetrics {
        let horizontalPadding: CGFloat = width >= 700 ? 32 : 20
        let spacing: CGFloat = width >= 700 ? 20 : 14
        let availableWidth = max(1, width - horizontalPadding * 2)
        let minimumTileWidth: CGFloat = width >= 700 ? 210 : 160
        let count = max(1, Int((availableWidth + spacing) / (minimumTileWidth + spacing)))
        let tileWidth = (
            availableWidth - CGFloat(max(0, count - 1)) * spacing
        ) / CGFloat(count)
        let columns = Array(
            repeating: GridItem(.fixed(tileWidth), spacing: spacing),
            count: count
        )

        return BoardGridMetrics(
            columns: columns,
            spacing: spacing,
            horizontalPadding: horizontalPadding,
            tileWidth: tileWidth
        )
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

private struct BoardGridMetrics {
    let columns: [GridItem]
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let tileWidth: CGFloat
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

private struct ReferenceTile: View {
    let entry: LookbookEntry
    let tileWidth: CGFloat
    private let imageStorage = ImageStorageService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = imageStorage.load(relativePath: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: imageWidth, height: imageHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if entry.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }
            .frame(height: 18, alignment: .leading)
        }
        .padding(8)
        .frame(width: tileWidth, alignment: .leading)
        .groupedCard(cornerRadius: 18)
    }

    private var imageWidth: CGFloat {
        max(1, tileWidth - 16)
    }

    private var imageHeight: CGFloat {
        imageWidth * 0.75
    }
}

struct LookbookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showsCopyConfirmation = false
    @State private var showsPromptFields = false
    @State private var editableNote: String

    let entry: LookbookEntry
    var boardNames: [String] = [LookbookBoard.defaultBoardName]

    private let imageStorage = ImageStorageService()

    init(entry: LookbookEntry, boardNames: [String] = [LookbookBoard.defaultBoardName]) {
        self.entry = entry
        self.boardNames = boardNames
        _editableNote = State(initialValue: entry.note)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    referenceSummaryCard(availableWidth: proxy.size.width)

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

                    structuredPromptCard
                    metadataCard
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
        }
        .navigationTitle("参考图详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: editableNote) { _, newValue in
            entry.note = newValue
            entry.prompt = PromptService.structuredPrompt(from: entry).fullText
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
                .accessibilityLabel(entry.isFavorite ? "取消收藏参考图" : "收藏参考图")

                Menu {
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
                } label: {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("移动到灵感集")
            }
        }
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
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text("来自现场取景 · \(entry.createdAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(entry.frameAspectRatio) · \(entry.lensPreset) · \(displayShotName)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SceneZeroTheme.infoAccent)
                }
            }

            Text("保存到 \(LookbookBoard.displayName(for: entry.boardName))")
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

    private var displayShotName: String {
        ShotType(rawValue: entry.shotType)?.displayName ?? entry.shotType
    }

    private var metadataCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            let lightRecords = lightRecords(for: entry)
            metadataRow("灵感集", LookbookBoard.displayName(for: entry.boardName))
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
        UIPasteboard.general.string = PromptService.structuredPrompt(from: entry).fullText

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
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
