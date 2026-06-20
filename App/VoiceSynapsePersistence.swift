import SwiftData

enum VoiceSynapsePersistence {
  static func makeModelContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      "VoiceSynapse",
      schema: VoiceSynapseSchema.schema,
      groupContainer: .identifier(AppGroup.id),
      cloudKitDatabase: .automatic
    )
    return try ModelContainer(for: VoiceSynapseSchema.schema, configurations: [configuration])
  }
}
