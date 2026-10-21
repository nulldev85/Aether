# Aether radio playback

The app uses unmodified AetherEngine 7.38.1, revision
`ce1670f8c6c4b8b11a8020e9c40a10c0d6da9823`. Its deployment minimum is iOS 18.
The display name, bundle identifier, Keychain service and saved library remain
the same. This is an engine replacement, with no station/library migration.
Only the remembered playback-format winners are isolated in a new engine cache,
so a VLC fallback cannot pin the new engine to a provider's inferior HLS stream.

## Playback

`AetherPlayerAdapter` implements the existing player seam. Every load requests
`LoadOptions.audioOnly`, `isLive`, disabled autoplay and suppressed display
matching. No view is bound to the engine. The app retains the Now Playing
dictionary and remote commands through `sharedOutputRole = .secondary`; that
setting relinquishes engine system-UI ownership, not audible playback. After
load the app restores `.playback` / `.default` / `.longFormAudio` audio settings.

Raw HTTP streams use a forward-only `IOReader`, which forces the upstream lean
audio host even when an AAC track is inside raw MPEG-TS. The upstream codec-only
native routing would otherwise give that URL to AVPlayer, which cannot play
the original provider's raw transport stream. The reader preserves media bytes,
removes optional ICY metadata blocks, forwards song titles to existing artwork
lookup, and bounds its queue to 4 MiB. Cancel wakes blocked consumers/producers.
FFmpeg decodes the original audio directly to PCM; it is not re-encoded to a
lower-bitrate intermediate. The reader has no internal retry loop; the existing
application retry/candidate/connectivity policy remains responsible for reconnects.

For `.m3u8`, AetherEngine's live ingest can feed the same audio-only host. Its
ingest does not accept every carriage (fMP4/packed-audio variants in particular),
so a failed HLS load can use the engine's native remote-HLS route. Video tracks
are disabled there. That compatibility route is shown explicitly in diagnostics;
it is not presented as the lean FFmpeg audio host. The application still prefers
dedicated audio renditions and retains every existing manual/broadcaster/EPG
song lookup. Native HLS timed metadata also feeds the existing parser.

The Wi-Fi/cellular buffer remains a target. The raw reader primes from the
declared ICY/probed audio bitrate, or a 192 kbps estimate when absent. Mixed TS
overhead/video and an undeclared bitrate prevent exact seconds; the queue is
byte-capped. Native HLS uses AVPlayer's advisory forward-buffer target; ingest
uses the upstream bounded queue. Diagnostics label the target as estimated.
The original 4–30 second preference and reconnect behavior remain available.

Real byte consumption is the raw route's progress signal: the upstream audio
clock can continue running while its demuxer is starved. Load generations retire
old tasks, metadata and callbacks before retuning. Cancellation never emits a
new-station error. Full provider URLs are registered with upstream log redaction;
app diagnostics expose format and track properties without a URL.

## Dependencies and packaging

`Packages/AetherAudioRuntime` pins 7.38.1 and selects `traits: []`, excluding the
optional LibTrueHD/LibDTSX object decoders. FFmpegBuild 3.7.1 and LibDovi 2.1.0
remain upstream dependencies. Decoder/video code still exists in that binary
distribution: smaller CPU work does not establish smaller download size or
battery use. Those require actual measurements. There is no VLC dependency.

CI runs the full unit/UI suites, including actual AetherEngine WAV and AAC-in-TS decoding and
renderer-clock check, ICY framing, HTTP refusal and blocked-reader cancellation.
The device packaging check verifies iPhoneOS, arm64, decoder dynamic linkage,
upstream resources, license texts and absence of VLC/object-decoder frameworks.
Before running the tests locally, run `bash scripts/make-audio-fixture.sh` with
FFmpeg installed. The generated transport stream is a synthetic 440 Hz tone.
Simulator compilation and tests cannot establish audible quality or background
route behavior on a physical iPhone.

For a device review, compare the same original station on the same speaker or
headphones. Check Radio/SXM/Dial, track changes and artwork, switching stations,
pause/resume/stop, lock-screen commands, a screen lock, a phone/Siri interruption,
Bluetooth/AirPlay, Wi-Fi/cellular transitions and a longer cellular buffer. Record
the playback path displayed by Stream diagnostics for any failing station.
