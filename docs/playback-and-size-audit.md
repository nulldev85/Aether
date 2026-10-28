# Aether playback and app-size review — 1.2.0 (8)

Review baseline: passed build7, commit953d9f8433a6d3084f18ee3246f9f06a2cce6272.
The user confirmed playback and the new design work on their phone. This review
keeps that audio configuration and makes targeted navigation/artwork repairs.

## Coverage and evidence

- Whole-app source inventory/reference/runtime-pattern scan:70 Swift files,
  approximately11,800 lines. Reviewed the station entry points, navigation,
  image loaders, state observers, persistence, network work and package setup.
- Detailed playback read: adapter/load generations, stream reader/backpressure,
  manifest probes, candidate selection, retry/stall/interruption recovery,
  metadata/source backoff, artwork and remote commands. Playback sources are
  byte-for-byte unchanged by this update.
- Passed workflow40608507284:307 unit tests,15 UI tests, credential checks and
  physical-device IPA packaging succeeded. No new CI status was polled.
- Downloaded its existing device artifact12782967836 and inspected the actual
  nested IPA, Info.plist, file inventory and embedded frameworks. Measurements
  below describe that exact build, not an estimate of the replacement build.

## Confirmed defects repaired

Station rows passed no listening list into the engine. The queue therefore
contained only previously played stations, often just the current station.
Favorites, personal Radio, SXM, the directory and search now supply their visible
order explicitly. Fresh playback URLs are resolved once when selecting a list.
The engine's existing navigation, format selection and audio path are retained.
Dial's single-station preview continues to have its intentional one-station queue;
it does not open every discovery result to resolve playlists speculatively.

The top-right utility buttons always selected their page, so a repeat tap did
nothing. Search and Settings now return to the last station tab on repeat tap.
This interprets the reported button as the top-right sliders utility.

The logo loader remembered failed URLs for the entire session in an unbounded
Set. It now retains at most150 failures, retries a URL after60seconds when
requested again, and limits individual requests to12seconds. Successful images
still share one request and use the existing150-image/32MiB decoded cache.
Cancelled SwiftUI image loads no longer publish results for a previous station.

## Bloat removed and useful safeguards retained

Removed the unreferenced PlaybackArtwork view and AetherNavigationButtonStyle,
plus four unused environment observations on Favorites, Settings and Root.
The local design checks were adjusted only for the deleted view boundary.
This is modest source/notification cleanup, not a claim of a measured frame-rate
or battery improvement.

Existing safeguards already present in playback:

- One audio adapter, explicit audioOnly/live options and secondary shared-output
  ownership, with the app owning Now Playing and remote commands.
- Compressed stream buffering is capped at4MiB. Priming has a bounded deadline
  and a2MiB byte cap; blocking read/producer waits wake on cancellation.
- Load generations reject old asynchronous adapter callbacks. Stop closes the
  reader, cancels loads, removes subscriptions and detaches metadata outputs.
- The0.5-second adapter timer checks progress; identical diagnostic samples are
  suppressed. No new timer, polling loop or background service was introduced.
- Source lookup backoff and stream metadata precedence already limit redundant
  song requests. Song images are decoded when metadata is built, not on every
  SwiftUI body evaluation. History is capped at50 stations.
- Vinyl uses Core Animation and redraws only for artwork/size changes. Its
  renderer and reduce-motion/background guards remain unchanged.
- Native HLS is an explicit compatibility fallback. Removing it would reduce
  supported stream carriage, so it remains part of the existing engine setup.

## Actual packaged size

| Build7 package area | Bytes |
| --- | ---: |
| IPA |11,856,382 (11.31MiB) |
| Uncompressed app |39,999,607 (38.15MiB) |
| App executable |28,862,080 |
| All other app resources |453,596 |
| avcodec framework |5,498,755 |
| swscale framework |1,097,011 |
| avformat framework |1,088,462 |
| dav1d framework |830,649 |
| avutil framework |760,460 |
| zvbi framework |524,134 |
| avfilter framework |439,242 |
| zimg framework |305,888 |
| swresample framework |139,330 |

No VLC, optional TrueHD/DTS:X frameworks, test bundles, xcresult output or synthetic
test stream were in this device IPA. App resources account for less than0.5MB;
the executable and codec libraries dominate. Required license notices remain.

The pinned upstream7.38.1 manifest exposes AetherEngine and AetherEngineSMB,
with traits for optional TrueHD/DTS:X object decoders. This app already disables
those traits. The core product still depends on the broader FFmpeg/Dovi stack;
audio-only runtime settings do not create a separate linkable audio-only product.
Source: [pinned upstream manifest](https://github.com/superuser404notfound/AetherEngine/blob/7.38.1/Package.swift).

A separately packaged upstream audio target is the next substantial size
opportunity. It requires upstream support and device validation; deleting linked
frameworks from the IPA is not a packaging repair. No dependencies were upgraded
or replaced during this review.

## Validation and limits

Added four SDK cache regressions: shared success, failed-request backoff,
post-backoff recovery and bounded negative-cache eviction. Added two UI scenarios:
real three-station Favorites selection/reordering, both navigation directions and
wraparound followed by search-queue replacement; and repeat utility opening/
closing on different station tabs during playback. All previous tests stay enabled.

The Windows workspace has no Swift compiler or Apple SDK. The new native tests
and the replacement IPA remain pending CI/device verification. This was a source
and package review, not an Instruments trace. Startup CPU, peak RAM and power on
the user's real provider/phone were not measured. Small persistent URL memo/probe
maps still grow with distinct streams; large-provider parsing/main-thread work
are possible profiling follow-ups. Their policies were left stable to retain
currently fast station loading. No broader no-leaks/no-bugs claim is made.

Before dispatch, all21 local design/preservation checks and seven package tests
passed, along with both unchanged credential scans, actionlint and diff checks.
The new full CI suite contains311 unit tests and17 UI scenarios; those new
native results are not yet known.
