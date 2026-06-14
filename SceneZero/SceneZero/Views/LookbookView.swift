import SwiftData
import SwiftUI
import UIKit

struct LookbookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LookbookEntry.createdAt, order: .reverse) private var entries: [LookbookEntry]

    private let imageStorage = ImageStorageService()

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Captures",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Capture an AR setup to create your first visual prompt.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink {
                                LookbookDetailView(entry: entry)
                            } label: {
                                HStack(spacing: 12) {
                                    thumbnail(for: entry)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(entry.prompt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Lookbook")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func thumbnail(for entry: LookbookEntry) -> some View {
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
        .frame(width: 72, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            imageStorage.delete(relativePath: entry.imagePath)
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

struct LookbookDetailView: View {
    let entry: LookbookEntry
    private let imageStorage = ImageStorageService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image = imageStorage.load(relativePath: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt")
                        .font(.headline)
                    Text(entry.prompt)
                        .font(.body)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = entry.prompt
                    } label: {
                        Label("Copy Prompt", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    metadataRow("Shot", entry.shotType)
                    metadataRow("Frame", entry.frameAspectRatio)
                    metadataRow("Lens", entry.lensPreset)
                    metadataRow("Guides", entry.showsCompositionGuides ? "On" : "Off")
                    metadataRow("Light", entry.lightPreset)
                    metadataRow("Color", entry.colorTemperature)
                    metadataRow("Intensity", "\(Int(entry.lightIntensity * 100))%")
                    metadataRow("Spread", "\(Int(entry.lightRadius * 100))%")
                    metadataRow("Look", entry.filterName)
                }
                .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}

#Preview {
    LookbookView()
        .modelContainer(for: LookbookEntry.self, inMemory: true)
}
