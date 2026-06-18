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
                LazyVGrid(columns: boardColumns, spacing: 16) {
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
                                    Button("Rename") {
                                        boardNameBeingRenamed = summary.name
                                        renamedBoardName = summary.name
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 36, height: 36)
                                        .liquidGlassCircle()
                                }
                                .buttonStyle(.plain)
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
                .padding()
            }
            .background(lookbookBackground)
            .navigationTitle("Lookbook")
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
                Section("Board") {
                    TextField("Name", text: $newBoardName)
                }
            }
            .navigationTitle("New Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showsCreateBoard = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
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
                Section("Lookbook") {
                    TextField("Name", text: $renamedBoardName)
                }
            }
            .navigationTitle("Rename Lookbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        boardNameBeingRenamed = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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

    private var lookbookBackground: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.08),
                Color.purple.opacity(0.06),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
                Text(summary.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(summary.count) references")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .liquidGlassRounded(cornerRadius: 20)
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
                    Text("Create Board")
                        .font(.headline)
                    Text("Tap to start a new inspiration set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .foregroundStyle(.primary)
            }
            .aspectRatio(1.36, contentMode: .fit)

            VStack(alignment: .leading, spacing: 3) {
                Text("New Inspiration Set")
                    .font(.headline)
                    .lineLimit(1)

                Text("Create a board")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .liquidGlassRounded(cornerRadius: 20)
        .accessibilityLabel("Create board")
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
                    .background(lookbookBackground)
            } else {
                ScrollView {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "No References",
                            systemImage: summary.systemImage,
                            description: Text("Capture a scene or move references into this board.")
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
                .background(lookbookBackground)
            }
        }
        .navigationTitle(summary.name)
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
                    Button(isArranging ? "Done" : "Arrange") {
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
                Text("Drag references into the scene order you want for this lookbook.")
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

    private var lookbookBackground: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.08),
                Color.purple.opacity(0.06),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        }
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

    let entry: LookbookEntry
    var boardNames: [String] = [LookbookBoard.defaultBoardName]

    private let imageStorage = ImageStorageService()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let image = imageStorage.load(relativePath: entry.imagePath) {
                        DetailImageView(image: image, availableWidth: proxy.size.width - 32)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Prompt")
                            .font(.headline)
                        Text(entry.prompt)
                            .font(.body)
                            .textSelection(.enabled)

                        VStack(spacing: 8) {
                            Button {
                                copyPrompt()
                            } label: {
                                Label("Copy Prompt", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .liquidGlassCapsule()

                            if let imageURL = imageStorage.fileURL(relativePath: entry.imagePath) {
                                ShareLink(item: imageURL) {
                                    Label("Export Image", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .liquidGlassCapsule()
                            }

                            if showsCopyConfirmation {
                                Label("Prompt Copied", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(14)
                    .liquidGlassRounded(cornerRadius: 20)

                    metadataCard
                }
                .padding()
            }
            .background(lookbookBackground)
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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

                Menu {
                    ForEach(boardNames, id: \.self) { boardName in
                        Button {
                            entry.boardName = boardName
                            try? modelContext.save()
                        } label: {
                            if entry.boardName == boardName {
                                Label(boardName, systemImage: "checkmark")
                            } else {
                                Text(boardName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                }
            }
        }
    }

    private var metadataCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            let lightRecords = lightRecords(for: entry)
            metadataRow("Board", entry.boardName)
            metadataRow("Shot", entry.shotType)
            metadataRow("Frame", entry.frameAspectRatio)
            metadataRow("Lens", entry.lensPreset)
            metadataRow("Guides", entry.showsCompositionGuides ? "On" : "Off")
            metadataRow("Light", entry.lightPreset)
            if lightRecords.count == 1, let light = lightRecords.first {
                metadataRow("Color", light.colorTemperature?.rawValue ?? entry.colorTemperature)
                metadataRow("Intensity", "\(Int((light.lightIntensity ?? entry.lightIntensity) * 100))%")
                metadataRow("Spread", "\(Int((light.lightRadius ?? entry.lightRadius) * 100))%")
            } else if lightRecords.count > 1 {
                metadataRow("Light Detail", "\(lightRecords.count) saved in layout")
            }
            metadataRow("Look", entry.filterName)
        }
        .font(.subheadline)
        .padding(14)
        .liquidGlassRounded(cornerRadius: 20)
    }

    private var lookbookBackground: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.10),
                Color.purple.opacity(0.08),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func lightRecords(for entry: LookbookEntry) -> [SceneObjectRecord] {
        guard let data = entry.layoutJSON.data(using: .utf8),
              let records = try? JSONDecoder().decode([SceneObjectRecord].self, from: data) else {
            return []
        }
        return PromptService.lightRecords(from: records)
    }

    private func copyPrompt() {
        UIPasteboard.general.string = entry.prompt

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
        .accessibilityLabel("Back")
    }
}

#Preview {
    LookbookView()
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
