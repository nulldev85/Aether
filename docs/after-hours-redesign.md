# Aether: After Hours

The user requested an entirely different dark app while retaining the rounded
font and spinning vinyl. This supersedes the former Lineup-style palette and
capsule requirements; the old reference document remains historical, not the
active visual specification. Base is freshly fetched main `f403d74` (PR 3 merged).

## Design

Near-black ink `#0B0D0C`, green-black surfaces `#161B18` / `#202822`, warm ivory
`#F4F1EA`, copper `#EFA66A`. Dark text, not white, sits on copper-filled buttons.
There are no purple/blue gradients, invented artwork, fake meters or quality
claims. The static tuning rule is decoration, not a live audio visualization.

- Editorial headings with tracked overlines and a tuning-scale signature.
- A low, rectangular studio navigation rail with a copper selection marker.
  All five destinations, optional native Glass and saved preferences remain.
- An inset mini-player strip, copper transport and the original live vinyl.
- Open station rows with separators, clear names and outlined favorite buttons;
  logos remain fitted, transparent and free of app-added background tiles.
- Redesigned Radio empty state and station collection headings/count labels.
- Search discovery offers genre shortcuts into the existing real search.
  They are suggestions, not claims that a provider carries those genres.
- Settings uses underlined categories and section headings outside quieter
  panels. Every existing control, value and binding remains available.
- New Dial controls, sign-in method selectors, fields, empty/error states and
  warm native chrome. Privacy, diagnostics, acknowledgements, editor and timer
  screens use the shared dark theme and explicit rounded fonts.
- The existing app icon drawing is recolored, not regenerated or replaced.

## Preservation and adaptation

The entire `IPTVRadio/Playback` tree and `VinylRecordView.swift` are unchanged.
Font.radio's implementation is pinned separately and unchanged. The logo-keying
and cache implementation is unchanged. Provider requests, source selection,
credentials, audio-session handling, retry policy and favorite persistence are
not redesigned. No new startup fetches, stream probes, dependencies or assets
downloaded from third parties are introduced.

The tested single-owner tab clearance arithmetic is retained. The full-player
card remains bottom-anchored and 140 points high, with at least 44-point
transport targets; vinyl remains centered with a compact-height scroll fallback.
The newly taller manual-station empty state is now scrollable, including larger
text sizes. Keyboard editing and native controls remain native.

## Validation and delivery

The former palette/capsule tests now assert the explicitly requested new design;
no behavior assertions or test suites were removed. Contrast checks extend to
all four surfaces and dark-on-copper text. Font, vinyl, engine and icon geometry
preservation checks remain. Full SDK geometry/native-font and all existing UI
tests remain enabled. Added UI coverage drives a real genre shortcut, filtered
result and Clear; screenshots cover the five tabs, player, sign-in, Dial and editor.

Version 1.1.0 (2). `RELEASE_NOTES.md` contains product-facing What's new bullets;
the main-only source-release job now includes them alongside exact source
metadata. A feature-branch review build does not publish a main/source release.
No merge is authorized. No Lineup, AppSource, website or live server is changed.

Windows has no Apple SDK. Offline checks cannot establish Swift compilation,
simulator rendering or physical-device playback. Dispatch the review build
once, return its URL, and do not poll/watch. Device review remains necessary.

Local result: all 16 design/preservation regressions and 7 synthetic bundle
checks passed. Official actionlint, YAML/full-suite gate checks, release-note
Python syntax and diff checks passed. Font helpers match fetched main exactly;
the complete audio, provider/data, package and vinyl-renderer trees are unchanged.
The compact-player UI test now targets its own named scroller, not the newly
scrollable Radio screen behind the sheet. Apple SDK/UI tests remain unrun here.
