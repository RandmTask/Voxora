import SwiftData

enum VoxoraPersistence {
  static func makeModelContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      "Voxora",
      schema: VoxoraSchema.schema,
      groupContainer: .identifier(AppGroup.id),
      cloudKitDatabase: .automatic
    )
    return try ModelContainer(for: VoxoraSchema.schema, configurations: [configuration])
  }
}
