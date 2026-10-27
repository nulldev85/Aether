# Aether workspace overhaul — 1.2.0 (6)

Active design specification. The user asked for a completely different look
and feel, minimal, sleek, professional and dim. The previous Graphite layout
is superseded. Its neutral palette remains, with no bright accent or gradients.

## Structure

- Top workspace header: Aether wordmark, Search and Settings utilities, then
  text navigation for Radio, SXM and Favorites. No bottom tab dock, capsule,
  floating navigation overlay or manual bottom-clearance arithmetic.
- A single persistent TabView retains independent navigation state. A single
  bottom safe-area inset owns a full-width playback shelf. Its vinyl remains.
  The saved translucency preference now changes the top header's material.
- Radio and Favorites are open two-column station presets: small position
  numbers, larger transparent logos, names and independent favorite controls.
  Accessibility text sizes use one column. Favorite reordering retains the
  existing store methods; manual edits/deletion live in each preset's Manage
  menu, with Add, Dial and Arrange in the page's management menu.
- SXM is a compact directory, with smaller logos and independently hittable
  play/favorite buttons. Search uses an underline field and genre grid. Dial
  moves location and genre into an expandable filter section.
- Settings has a root menu and real Account/Stations/Playback/App pages,
  replacing the category strip and bordered setting cards. Existing bindings,
  diagnostics, privacy, cache, filtering, account and audio-output options stay.
- Sign-in uses underline fields with explicit keyboard focus/Next navigation.
  The manual editor is a simple scrolling form with underline fields.
- Full player: centered original spinning disc, left-aligned song information,
  unboxed bottom transport and a small square primary control. Record stage,
  scroll fallback, dismissal, sleep, routing, retry and station actions remain.

SF Pro Rounded helpers and VinylRecordView are byte-for-byte preserved after
normalizing line endings. Playback, Core, Library and Packages are unchanged.
The existing muted app icon already matches this palette; its drawing and
asset were not changed. Provider artwork keeps its colors and has no tiles.

## Reported build failure and interaction repairs

Run 40586810750 was inspected once after the user reported failure. Compilation
and all 307 unit tests passed. The 13 UI tests had four failures: two player
tests exposed a 21.33-point Previous target, login lost password keyboard focus,
and the manual-station swipe did not expose Delete. Packaging was skipped.

Player label rectangles now define their interactive shapes, including sleep,
retry and Close. Existing actual-frame >=44-point assertions remain. Sign-in
has explicit FocusState navigation; every UI scenario now requests portrait and
awaits the actual portrait frame so the landscape test cannot leak orientation
into the next scenario. Manual deletion is exercised through the new Manage
menu. Grid reorder tests compare reading order in both dimensions.

Existing UI scenarios remain. Added real favorite-button isolation and account
sign-out cancellation/back-navigation regressions. The translucency test now
changes/restores the actual native switch and verifies navigation/playback in
both states. No playback assertions, hit-target thresholds or deadlines relaxed.
The obsolete floating-dock geometry test is replaced by workspace metrics and
actual header/shelf separation in UI tests.

Windows has no Apple SDK. Compilation, native UI behavior, screenshots and IPA
validation of this revision remain pending GitHub Actions. Do not claim visual
device verification or a passing SDK run based on the local source checks.
Start one authorized review build, return its link, and do not poll or watch it.
Nothing is merged or published to the app feed.

Local validation: 19 design/preservation checks, seven package-verifier
regressions, both original credential scripts, actionlint and diff checks
passed. There is no new signing, workflow gate, backend or package dependency.
Settings shows both version and build so the installed revision can be checked.

## Build 5: accessibility repair

After the user reported run 40592542055 failed at 4be37ad, its completed jobs
and simulator job 122500193154 log were inspected. Compilation and all 307
unit tests passed. Of 15 UI tests, eight passed and seven failed. Six failures
stopped at a missing `miniplayer.open`; the other was Dial's location field.
The unit/UI step took 17m50s. Device packaging was skipped.

Downloaded the existing test-results artifact 12775248879, verified its source
SHA, and decoded its saved XCTest accessibility snapshots locally. In the
Now Playing scenario, Open (175x54), Pause (44x44) and Stop (44x44) buttons were
present with the expected playing-station value, but all three had the parent
`aether.playback.shelf` identifier. The new shelf HStack needed an explicit
accessibility container. `.accessibilityElement(children: .contain)` now gives
the parent its own element and retains independently accessible child actions.
Apple documents this child behavior at:
https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain

Dial's group-wide filter identifier was replaced by an identifier on the actual
expand/collapse button. Expanded fields keep their own identifiers. The view
keeps the same filter state, values, layout and existing search implementation.
The UI regression now enters a location, collapses/reopens and checks that its
value persists. The workspace regression requires all three distinct player
buttons within the shelf, with their actual >=44-point frames and hittability.
Failed UI scenarios now print their native hierarchy so future failures can be
diagnosed from the job log. All 15 UI tests and original thresholds remain.

The earlier login regression, favorite-action isolation, grid reordering,
SXM/search and settings/account tests passed in the inspected run. Player
presentation/transport and deletion assertions were not reached in the six
blocked scenarios and remain unverified until the replacement run completes.
No playback, vinyl, font, dependency, credential or workflow-gate changes.

Build-5 local checks: all 20 design/preservation tests and seven synthetic
package-verifier tests passed, as did the two unchanged credential scripts,
official actionlint and diff checks. Native SDK/UI verification remains pending.

## Build 6: scope full-player geometry checks

The user reported run 40596888426 at 495228a failed. Read its completed jobs
once and simulator job 122514954501 log once. Compilation, all 307 unit tests
and 14 of 15 UI tests passed, including the player control identities, Dial
input/collapse preservation, manual add/play/delete and compact player controls.
The unit/UI step took 16m49s; packaging was skipped.

The sole failure was the full-player record's horizontal-center assertion:
the unscoped first-match query selected the persistent mini-player's record
behind the modal (frame24,752,54,54; centerX51). The same failure hierarchy shows
the actual full-player record at40,193.3,313,313 (centerX196.5 on a393-point
screen). Its centerY349.8 also matches the existing expected349.65 within3pt.
No artwork layout or playback-engine bug was inferred from that failed selector.

The presented player now has its own explicit accessibility container/ID.
Record, status, transport and compact-scroll queries are scoped to that screen;
tests require exactly one presented screen and one record within it. Original
horizontal2pt, vertical3pt, square1pt and >=44pt touch-target checks remain.
Closing/swiping must actually remove the presented screen before mini-player
checks, because background elements can remain in the native hierarchy.

Failure logging now checks totalFailureCount rather than hasSucceeded during
teardown; the latter was still false while successful cases were finishing.
This avoids dumping successful hierarchies. All15 UI tests remain enabled.
Only accessibility metadata/test selection and build numbering changed. Vinyl,
font, geometry, playback, icon, palette, dependencies and CI gates are unchanged.

Build-6 local validation: 21 design/preservation tests and seven package tests
passed. Both credential scripts, official actionlint and diff checks passed.
No Apple SDK is installed locally; the replacement SDK/UI run remains pending.
