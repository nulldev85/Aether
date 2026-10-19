# Logo and rounded-font follow-up

The Lineup-style station row had added a dark rounded tile around its logo.
That tile is removed. The 64-point layout footprint stays the same, so names,
favorites and playback indicators do not shift. Transparent station marks now
sit directly on their row. Existing provider-background keying, fitted artwork,
caching and the tile-free Dial artwork are preserved; no new image downloads
or image-processing work are introduced.

Root-level font inheritance was not enough for the requested Settings polish.
Settings switches now use explicit SF Pro Rounded Text labels and their original
bindings; labeled values explicitly style both columns. Navigation rows, slider
labels/values, native form headers/footers and detection-rule editors also set
their own rounded fonts. Diagnostics, acknowledgements, station fields, Dial,
sign-in choices, reorder labels and Sleep Timer receive the same explicit
treatment. Headings retain Heavy; supporting text keeps the existing readable
regular/medium/semibold hierarchy. Font text styles retain Dynamic Type.
Native iOS alerts, keyboard and output-picker internals remain system-owned.

No palette, icon, playback, audio-session or vinyl-rendering changes are included.
The existing offline engine/vinyl preservation checks remain enabled. New offline
source regressions cover tile-free logos, explicit switch/value labels and all
app-owned text inputs. The SDK font test covers rounded native sizes/weights and
dynamic SwiftUI styles. The Settings UI regression retains all existing checks,
captures every category, and exercises switch binding persistence and restoration.
Existing logo-background pixel tests remain enabled unchanged.

Windows cannot compile or render iOS views. Offline checks are not SDK/device
validation. The full simulator suite and physical-device IPA packaging remain
enabled. Dispatch once, return the build URL, do not poll/watch, and do not merge.

Local validation: all 12 design regressions and 7 synthetic bundle checks pass;
workflow YAML/build-gate and diff-whitespace checks pass. Bundle checks required
an unsandboxed rerun because Windows denied temporary-directory writes, not
because of a packaging assertion failure. The new Swift/UI tests are unrun
locally and remain pending CI.
