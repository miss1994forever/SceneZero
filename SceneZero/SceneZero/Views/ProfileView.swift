import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var entries: [LookbookEntry]
    @Query private var boards: [LookbookBoard]

    @AppStorage("usesRealityKitModelLighting") private var usesRealityKitModelLighting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text("S")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Color.accentColor, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("SceneZero Creator")
                                .font(.headline)
                            Text("Local workspace")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Library") {
                    statRow("Captures", value: entries.count, systemImage: "photo.on.rectangle")
                    statRow(
                        "Boards",
                        value: boards.count + 2,
                        systemImage: "rectangle.stack"
                    )
                    statRow(
                        "Favorites",
                        value: entries.filter(\.isFavorite).count,
                        systemImage: "heart"
                    )
                }

                Section {
                    Toggle(isOn: $usesRealityKitModelLighting) {
                        Label("3D Model Lighting", systemImage: "lightbulb.max")
                    }
                    Label("Export Lookbook", systemImage: "square.and.arrow.up")
                    Label("Capture Preferences", systemImage: "slider.horizontal.3")
                    Label("About SceneZero", systemImage: "info.circle")
                } header: {
                    Text("Workspace")
                } footer: {
                    Text("Lighting Overlay stays available for stable real-time light previews. 3D Model Lighting adds RealityKit lights to virtual models and may reduce stability on some devices.")
                }
                .foregroundStyle(.primary)

                Section {
                    Text("Profile is local-only in this course version. Accounts, cloud sync, and public sharing are future work.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func statRow(_ title: String, value: Int, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value, format: .number)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [LookbookEntry.self, LookbookBoard.self], inMemory: true)
}
