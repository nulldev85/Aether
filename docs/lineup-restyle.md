# Lineup's iPhone style in Aether

This supersedes the limited shell refresh: the user explicitly requested
Lineup's style for the **entire app**, including both players. Only the spinning
vinyl was excluded from the redesign. Prior tests freezing the old player
palette/views were therefore replaced with the newly requested preservation
boundary, not disabled to make an unrelated failure pass.

## Actual reference

Read-only source: `nulldev85/NullSports`, main commit
`97ce5e768b4f33f3271e9f2c27eec2beda93ab3f`. The working Lineup checkout was
not modified. No Lineup build, deployment, merge or CI inspection is involved.

The relevant source is recorded in `lineup-style-reference.json`: LineupStyle,
LineupFont, LineupAccent, LineupApp, MobileNavigationStyle and MobileViews. The current
`.inter` helpers actually use Apple's **SF Pro Rounded**, despite their older
names/comments. Aether uses that native face; it does not add Inter font files.

Shared measurements and colors:

- Ground `#1C1C1E`, panels `#2C2C2E`, selected wells `#3A3A3C`.
- White names, 66%-white secondary text, `#CCCCCC` captions, `#9E9EA5` quiet text.
- Default broadcast red `#FF3347`; native Settings icon-tile colors.
- Continuous 24-point panels, 14-point compact controls, 20-point margins/insets,
  14-point panel gaps; heavy uppercase 15-point panel captions with 0.4 tracking.
- Floating navigation: 20-point side margins, 4-point capsule padding, 54-point
  items, neutral selected well/white icon, 20-point bottom gap on home-indicator
  phones and 8 points otherwise. Glass remains opt-in on iOS 26+.

Aether keeps its destinations and radio functions, rather than copying Sports,
TV Guide, Library or provider/server behavior from Lineup. Default appearance is
fixed dark, like Lineup. The old light/system preference is retained as legacy
data but no longer presented as a palette choice. Existing explicit navigation
preferences are retained; otherwise the Lineup floating bar is now the default.

## Whole-app coverage

Radio/SXM/Favorites rows, Search, Dial, sign-in, launch, empty/error states,
Settings/categories/forms, diagnostics, privacy, acknowledgements, Sleep Timer,
mini player and full Now Playing use the shared palette and rounded type.
The full player has Lineup-style controls and a persistent Close button; closing
does not stop playback. Mini player and navigation are separate compact panels.
Each tab reserves their height once, including scaled player height and the
physical bottom gap, without also padding individual lists for the same controls.

The Aether icon retains its drawing/geometry and changes only to charcoal,
white, grey and red. It is rendered from the original local drawing script,
not generated imagery. The vinyl drawing/animation source is byte-for-byte
unchanged. Its missing-artwork accent naturally follows the shared red palette;
its artwork, rotation, pause/resume and Reduce Motion guards remain intact.

## Scope and verification

All files in `IPTVRadio/Playback` are unchanged from `275f76a`, including the
pending AUX-call repair. A normalized aggregate digest is pinned in the reference
snapshot and checked offline. This visual update does not establish or change
the physical-phone result of that earlier repair.

Nine offline checks cover the reference tokens/measurements, one dark rounded
theme, text contrast, reference accent contrast, unchanged vinyl/engine code,
icon geometry/opaque dimensions, one navigation clearance owner and accent asset.
The red-control contrast check is not a claim that every small white-on-red
label meets body-text AA: this follows Lineup's exact reference color.

Four new SDK tests check resolved palette values, real clearance calculations,
the UIKit rounded face and the real vinyl layer spinning/pausing/resuming.
The navigation-default persistence test now verifies the requested floating
default and still tests both saved values. Existing UI tests retain their full
navigation, playback, station-switching, swipe-dismissal, favorites and search
assertions, and additionally exercise Close without stopping playback.

Windows has no Apple SDK. Offline success is not Swift compilation, simulator
layout validation, audible playback proof or a physical AUX-call result.
The full simulator suite and real device IPA packaging remain enabled. CI is
dispatched once with its link returned; no polling/watching or merge.
