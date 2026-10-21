import AetherEngine

/// The app's dependency boundary; these are the upstream public types, not a
/// second playback implementation or a patched copy of AetherEngine.
public enum RadioAudioRuntime {
    public typealias Engine = AetherEngine
    public typealias Options = LoadOptions
    public typealias Source = MediaSource
    public typealias ByteReader = IOReader
    public typealias Track = TrackInfo

    public static func registerSecret(_ value: String) { _ = EngineLog.registerSecret(value) }
}
