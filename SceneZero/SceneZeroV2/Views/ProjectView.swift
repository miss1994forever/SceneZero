import SwiftData
import SwiftUI

struct ProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SceneProject.updatedAt, order: .reverse) private var projects: [SceneProject]
    @Query(sort: \LookbookEntry.createdAt, order: .reverse) private var entries: [LookbookEntry]

    @State private var showsCreateProject = false
    @State private var showsSettings = false
    @State private var projectName = ""
    @State private var projectDescription = ""

    private let imageStorage = ImageStorageService()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    continueCreatingSection
                    projectsSection
                }
                .padding()
            }
            .background(SceneZeroTheme.background)
            .navigationTitle("项目")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("设置", systemImage: "gearshape") {
                        showsSettings = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("设置")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建项目", systemImage: "plus") {
                        projectName = ""
                        projectDescription = ""
                        showsCreateProject = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("新建项目")
                }
            }
            .sheet(isPresented: $showsCreateProject) {
                createProjectSheet
            }
            .sheet(isPresented: $showsSettings) {
                ProfileView()
            }
        }
    }

    private var continueCreatingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("继续创作")
                .font(.title2.weight(.bold))

            if let entry = entries.first {
                NavigationLink {
                    LookbookDetailView(entry: entry)
                } label: {
                    HStack(spacing: 14) {
                        previewImage(for: entry)
                            .frame(width: 92, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(entry.projectID.flatMap(projectName(for:)) ?? "未归档参考包")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(SceneZeroTheme.accent)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .groupedCard(cornerRadius: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("继续编辑：\(entry.title)")
            } else {
                ContentUnavailableView(
                    "还没有参考包",
                    systemImage: "viewfinder",
                    description: Text("去现场捕捉第一个空间、光影或镜头想法。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .groupedCard(cornerRadius: 20)
            }
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的项目")
                    .font(.title2.weight(.bold))
                Spacer()
                Text("\(projects.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if projects.isEmpty {
                Button {
                    showsCreateProject = true
                } label: {
                    ContentUnavailableView(
                        "创建第一个项目",
                        systemImage: "film.stack",
                        description: Text("把参考包、场景和镜头想法归到同一部作品。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .groupedCard(cornerRadius: 20)
                }
                .buttonStyle(.plain)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(projects) { project in
                        NavigationLink {
                            ProjectDetailView(
                                project: project,
                                entries: entries(for: project)
                            )
                        } label: {
                            ProjectCard(
                                project: project,
                                entries: entries(for: project),
                                imageStorage: imageStorage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section("项目") {
                    TextField("片名或项目名称", text: $projectName)
                    TextField("一句话创作方向（可选）", text: $projectDescription, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showsCreateProject = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { createProject() }
                        .disabled(trimmedProjectName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var trimmedProjectName: String {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func entries(for project: SceneProject) -> [LookbookEntry] {
        entries.filter { $0.projectID == project.id }
    }

    private func projectName(for id: UUID) -> String? {
        projects.first(where: { $0.id == id })?.name
    }

    private func createProject() {
        let project = SceneProject(
            name: trimmedProjectName,
            projectDescription: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(project)
        try? modelContext.save()
        showsCreateProject = false
    }

    @ViewBuilder
    private func previewImage(for entry: LookbookEntry) -> some View {
        if let image = imageStorage.load(relativePath: entry.imagePath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
    }
}

private struct ProjectCard: View {
    let project: SceneProject
    let entries: [LookbookEntry]
    let imageStorage: ImageStorageService

    var body: some View {
        HStack(spacing: 14) {
            cover
                .frame(width: 88, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("尚未添加创作方向")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label("\(entries.count) 个参考包", systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SceneZeroTheme.accent)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .groupedCard(cornerRadius: 20)
    }

    @ViewBuilder
    private var cover: some View {
        if let path = entries.first?.imagePath,
           let image = imageStorage.load(relativePath: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "film.stack")
                .font(.title2)
                .foregroundStyle(SceneZeroTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SceneZeroTheme.accentSoft)
        }
    }
}

private struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let project: SceneProject
    let entries: [LookbookEntry]

    @State private var projectDescription: String

    init(project: SceneProject, entries: [LookbookEntry]) {
        self.project = project
        self.entries = entries
        _projectDescription = State(initialValue: project.projectDescription)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("创作方向")
                        .font(.headline)
                    TextEditor(text: $projectDescription)
                        .frame(minHeight: 92)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(SceneZeroTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(14)
                .groupedCard(cornerRadius: 20)

                HStack {
                    Text("参考包")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text("\(entries.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if entries.isEmpty {
                    ContentUnavailableView(
                        "项目还没有参考包",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("在现场保存参考包后，可从详情页将它归入这个项目。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(entries) { entry in
                            NavigationLink {
                                LookbookDetailView(entry: entry)
                            } label: {
                                ProjectReferenceRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(SceneZeroTheme.background)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: projectDescription) { _, newValue in
            project.projectDescription = newValue
            project.updatedAt = .now
            try? modelContext.save()
        }
    }
}

private struct ProjectReferenceRow: View {
    let entry: LookbookEntry
    private let imageStorage = ImageStorageService()

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = imageStorage.load(relativePath: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 72, height: 54)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.note.isEmpty ? entry.locationName : entry.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .groupedCard(cornerRadius: 16)
    }
}

#Preview {
    ProjectView()
        .modelContainer(for: [LookbookEntry.self, InspirationAsset.self, LookbookBoard.self, SceneProject.self], inMemory: true)
}
