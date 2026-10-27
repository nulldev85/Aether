# Minimal Graphite revision

The user rejected After Hours and requested minimal, sleek, professional and dim.
This replaces that look, not just its copper accent. The historical After Hours
document is no longer the active visual specification.

Changes:

- Neutral near-black/charcoal surfaces, soft gray text and restrained gray accents.
  All primary palette channels are capped at 215 and their channel spread at 24;
  no white, copper, green-black, neon or highly saturated custom chrome.
- Dark gray button fills instead of bright accent fills. Text, muted semantic
  warnings/errors and small accent labels retain measured 4.5:1 contrast against
  all four surfaces; primary button text exceeds 7:1.
- Tuning scales, overlines, slogans, tracking and decorative control borders
  removed. Headings are compact and functional. Shared icons are unboxed.
- Navigation has a subdued selection well. Mini-player accent stripe removed;
  previous/next controls are plain and main transport uses a quiet gray circle.
- Search, sign-in, Dial, Settings, privacy, diagnostics and editor copy simplified.
  Manual-station actions are compact single-line controls, with scrolling retained.
- The original icon drawing is recolored to the same muted palette. Station logos
  and album art retain their colors; no app-added logo plates are introduced.

SF Pro Rounded helpers are unchanged. The vinyl renderer, animation guards,
bottom-anchored 140-point controls, centered record stage and compact-height
fallback remain. Entire Playback/Core/library/package trees are unchanged.
All existing behavioral tests stay enabled. Only superseded design expectations
were updated; an additional dim-neutral/no-decorative-chrome regression was added.

Version 1.1.0 (3). Release notes were revised before distribution. Nothing is
merged, released to main or changed in Lineup, AppSource or live services.
Previous review build results were not read or polled.

Validation: 17 offline design/preservation checks and 7 synthetic bundle checks
passed. Official actionlint and diff checks passed. No Apple SDK is installed
on this Windows machine: native Swift/UI/device validation remains pending.
Dispatch one review build, return its link, and do not poll/watch it.

## Credential-scan job repair

The user reported the credential-scan job failed in run 40584423432 at
98c3b7e. Its completed job 122472024829 was inspected: committed-secret and
unsafe-logging checks passed, as did all seven bundle-verifier regressions.
The sole failure was the icon-preservation test's hash of `ast.dump` output.
Python versions format empty AST fields differently, so that debugging string
is not a portable integrity contract.

The test now fingerprints normalized drawing source with only quoted hex
colors masked. The expected fingerprint was independently obtained from the
original merged icon generator at f403d74; the current generator matches it.
A regression accepts recoloring and Windows line endings while rejecting
canvas-size, record-coordinate and corner-radius changes. No icon, app source,
credential checks, playback code or SDK/UI assertions changed. The workflow
step now correctly names Graphite rather than Lineup. The simulator job was
not inspected again; its result is unconfirmed.

Repair validation: 18 design/preservation checks and all seven bundle checks
passed locally. Both credential-check scripts were run unchanged in Git Bash
and passed; the existing Logger-declaration warning remains non-fatal. Official
actionlint and diff checks passed. SDK/UI/device validation remains pending.
