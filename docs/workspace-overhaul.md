# Aether workspace overhaul — 1.2.0 (9)

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

## Build 7: native Settings assertions and toolbar labels

The user reported run 40601935393 at 79c16f4 failed. Its completed jobs and
simulator job 122531953612 log were inspected once. Compilation and all 307
unit tests passed. Fourteen of 15 UI tests passed, including the full player:
record centering, Close, reopening, Next, swipe dismissal and Stop, plus the
compact scroll/control regression. The sole failure was the three-second
predicate waiting for the navigation preference to return to `0`. The failing
hierarchy shows both the labeled switch and its native child already at `0`.
The unit/UI step took 16m22s. Device packaging was skipped.

Downloaded the existing test-results artifact 12780550613 and confirmed its
source SHA. The result summary confirms 321 passes, one failure and no skips.
Reviewed all 16 saved screenshots as well as both Settings tests and the
production binding/header code. There is no asynchronous preference write:
the native toggle updates a published binding and UserDefaults synchronously.
The exact reason XCTest's timed predicate missed the state is not proven;
the logs show multi-second accessibility reads during its three-second budget.

Both Settings scenarios now resolve an unambiguous native Switch, require it
to be hittable, verify the exact binary value, perform one real tap, and read
the exact new value from a fresh native query after that action completes.
There is no timer predicate or retained Any/firstMatch element across page
navigation. These are stricter checks than accepting any changed value. The
navigation preference must retain both its changed and restored values across
leaving/returning, and SXM plus the playback shelf must remain usable. Cellular
retains its existing navigation/persistence and restore assertions. All 15 UI
scenarios remain; no production setting, engine or CI gate was changed.

Screenshot review also exposed a real visible defect: Cancel in the station
editor wrapped into a narrow two-line label. Toolbar label sizing now reserves
the full single-line text width and a 44-point minimum height. The same shared
style also covers Save and the sleep timer's Done. The font and dim palette are
unchanged. Native verification of the revised label remains pending CI.

All 21 local design/preservation checks, seven package checks, both original
credential scripts, workflow lint and diff checks passed before dispatch. No
Apple SDK is installed locally, so do not claim a successful SDK/UI/IPA build
until the user reports the replacement result. Do not poll or watch its run.

## Build 8: listening queues, utility toggle and cleanup

The user confirmed build7 passed and the design looks good on their phone.
Completed run40608507284 at953d9f8 was inspected once:307 unit tests,15 UI tests,
credential scan and device IPA packaging all passed. Their device report exposed
a coverage gap: the full-player UI scenario preloaded a queue, while real station
rows called play with no list. The new regression starts through actual rows.

Each StationRow now requires its displayed playback collection. Favorites and
Radio supply saved order; SXM/directory and search supply their visible results.
Saved station URLs are refreshed for the whole queue at selection time. Manual
station resolution uses one dictionary, avoiding repeated scans. Next/Previous
retain the engine's existing wraparound and remote-command behavior.

The top-right Settings/Search utilities toggle back to the last Radio/SXM/
Favorites tab. This interprets the user's "top-right menu" as the sliders icon;
an optional clarification was requested while independent work continued.

Removed two unreferenced UI types and four unused environment subscriptions.
Logo failures now have a bounded150-entry cache and60-second retry backoff,
instead of permanent session failures. Requests have12-second timeouts. Existing
32MiB/150-image decoded cache and shared in-flight requests remain. Cancelled
row/mini/full-player image loads cannot publish obsolete logos.

Added four logo-cache SDK tests and two actual UI regressions: arranged three-
station Favorites navigation/wraparound with search-queue replacement, and
repeated utility opening/closing during playback. Existing15 UI scenarios remain.
UI fixtures clear only mock favorites at launch so scenario order cannot leak
between tests. No production favorites or storage format is cleared or changed.

Full audit, measured build7 package sizes and follow-up limits:
[Playback and size audit](playback-and-size-audit.md). Audio engine, all Playback
sources, Core, package versions/traits, font helpers, spinning vinyl, icon and
workflow gates remain unchanged. New SDK/UI checks require the next CI run.

## Build 9: Favorites test compilation

The user reported40617226042 at845271e failed. Inspected completed jobs once
and simulator job122582447890 log once. The application compiled; XCTest did
not run because the new Favorites UI test failed to compile at lines302/306:
Swift could not type-check the chained XCUIElement sorting expression, then
could not infer the map key-path root. Device packaging was skipped.

The test now snapshots labeled CGRect values into an explicitly typed array,
compares a separately typed CGFloat distance with an ordinary if branch, and
maps the known tuple name with an explicit closure. It retains the exact
PopRocks/Hits1/Octane visible-order assertion,2-point row tolerance, both arrow
directions, wraparound and search-queue replacement. Native queries are sampled
once per station rather than repeatedly inside sorting. No app behavior,
playback/cache/menu implementation or CI gate changed. All17 UI scenarios and
311 unit tests remain pending execution on the replacement SDK run.
