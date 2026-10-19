# Aether: shell refresh and car-call recovery

## Scope

The browsing shell uses warm paper/cream and burnt amber in light mode,
charcoal/cream and muted amber in dark mode. Backgrounds are flat; list rows,
headings, settings groups, search and navigation share a restrained hierarchy.
Radio, SXM, Favorites, Search, Dial, sign-in and settings keep their functions.
The icon is rendered from the existing drawing script: only its five color
literals change. Geometry, placement, strokes and antialiasing are unchanged.
No generated imagery, new mark, dependency or remote asset is introduced.

The existing `AetherTheme`, mini player, full Now Playing screen, vinyl record,
shared playback artwork and global accent asset remain unchanged. New shell
views use `AetherInterface`; player presentation sites explicitly retain the
old tint. Native player-sheet navigation appearances remain as before.
Offline tests pin these boundaries, the icon drawing AST excluding colors,
and 4.5:1 text/control contrast in both appearances. Existing UI tests keep
screenshots of the shell and unchanged player in the result bundle.

## Call recovery

Two integration gaps were found by inspection, not by reproducing a physical
phone call: a route-return callback could resume inside an active interruption
and clear its saved station, and demuxed bytes could incorrectly stand in for
audio output when confirming recovery.

Main-queue notifications are handled synchronously so queued tasks cannot
reorder them. An explicit interruption latch blocks route-triggered resume until the call
ends. The session is reactivated first. If listening on an external output and
the cord/output is actually missing, playback remains paused rather than
starting on the phone speaker; a returned external route can complete recovery.
Manual pre-call pause and explicit Stop remain authoritative.

The Aether adapter reopens the exact already-selected live-stream URL and buffer
target after an interruption. This discards stale compressed data and creates
a fresh renderer instead of reusing an output iOS may have flushed. It does not
select another engine or change the station's format/quality preference.
Regular user pause/resume is unchanged. Recovery confirmation uses the output
clock rather than byte intake. Missing/frozen readings cause a bounded recovery
of the current candidate, retaining the existing retry/fallback policy.

References: Apple's [audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
and [route-change guidance](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).

## Validation boundaries

Nine new SDK regressions cover exact call/route ordering, duplicate end events,
actual unplug/route return, manual pause, Stop, loading interrupted by a call,
and frozen/missing output progress. The existing real AAC-in-TS engine test now
also requires a fresh audio-only renderer to become ready after interruption
recovery and rejects any changed request URL. All existing suites remain enabled.

Local verification: seven package-verifier tests and seven design-boundary/
contrast tests passed. Workflow YAML and the full-simulator-suite packaging
gate were checked; `git diff --check` passed. The package tests required the
normal authorized rerun outside Windows sandbox Temp restrictions.

Windows has no Apple SDK. Local Python checks cannot establish Swift compilation,
iOS rendering or audible recovery. Simulator/IPA and physical AUX-call checks
remain pending until their actual results are reported. No CI polling/watching.

On device, test with the same AUX cable: play, accept a call, hang up with the
phone locked, and confirm live audio returns on AUX. Also unplug during a call
and verify no speaker playback; reconnect and verify recovery. Check manual
pause and Stop do not auto-resume, and review light/dark appearance, larger text,
station switching and both navigation styles without altering the player.
