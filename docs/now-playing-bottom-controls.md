# Now Playing: bottom controls and centered vinyl

User's follow-up screenshot showed the transport card in the scrolling content,
leaving a large empty area below it. Only full-player layout is changed here.

- Transport lives in a bottom safe-area inset, with 12 points of clearance above
  the home-indicator safe area. It no longer scrolls with the track details.
- The card is 140 points tall instead of 176: 64-point primary transport,
  48-point skip buttons, 44-point secondary row, 8-point row gap and 12-point
  vertical padding. No action is removed and transport targets remain above 44.
- The disc is centered on both axes in its actual available stage between the
  header and track details, not positioned from the whole screen's height.
  Its diameter fits the stage; the original renderer/rotation is unchanged.
- A compact-height/large-text fallback scrolls just the record and details.
  Bottom controls and Close remain outside that scroll view.

No mini-player, typography, palette, icon, station-logo, audio-session, stream or
engine changes. Existing offline engine/vinyl preservation checks stay enabled.
New SDK geometry coverage checks fitted diameters, touch targets and card height.
UI coverage checks portrait centering/bottom clearance and compact-height
scrolling without moving the controls, while retaining existing playback tests.

Windows has no Apple SDK; local source/bundle checks are not iOS rendering or
device verification. Full simulator tests and iPhone IPA packaging remain enabled.
Build once, return its link, do not poll/watch and do not merge.

Local checks: 13 design regressions and 7 synthetic bundle checks passed;
workflow YAML/full-suite gate and diff checks passed. The Swift geometry and
UI-layout assertions are unrun locally and remain pending CI/device validation.
