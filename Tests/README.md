# A Life Along the River — native checks

Hero motion and exploration fog add **8,056** checks to the suites below (8,022 motion + 34 fog), for **20,110** total checks on the current dataset.

```sh
hero_fog_checks_dir=$(mktemp -d /tmp/scroll-hero-fog-checks.XXXXXX)
xcrun swiftc -swift-version 6 App/AdventureHeroMotion.swift Tests/AdventureHeroMotionChecks.swift -o "$hero_fog_checks_dir/hero"
"$hero_fog_checks_dir/hero"
xcrun swiftc -swift-version 6 App/ScrollArchive.swift App/AdventureArchive.swift App/AdventureWorldArchive.swift App/AdventureWalkPath.swift App/WorldFogProgress.swift Tests/WorldFogChecks.swift -o "$hero_fog_checks_dir/fog"
"$hero_fog_checks_dir/fog"
```

Run from the repository root on macOS with Swift 6. These compile production Foundation/Observation models directly. No simulator, project configuration, purchase service, or real player defaults are touched. Each model suite uses fresh isolated UserDefaults suites and removes only those suites afterward.

The current fixtures are the unchanged historical `story.json` plus the latest supplied **9,832 × 724** `World/world.json` (6 scenes, 44 road points, 13 places). Story remapping adds the paper-boat quest in memory, for 17 total missions. The historical Qingming coordinates and path remain reference assets, not the active world. Geometry checks read source metadata and the actual JPEG dimensions rather than embedding a panorama size.

## Models, postures, world migration, and rewards

```sh
adventure_checks_dir=$(mktemp -d /tmp/scroll-adventure-checks.XXXXXX)
for adventure_suite in AdventureModelChecks AdventurePostureChecks AdventurePathAndCricketChecks AdventureWorldChecks AdventureDepartureChecks; do
  xcrun swiftc -swift-version 6 \
    App/ScrollArchive.swift App/AdventureArchive.swift App/AdventureWorldArchive.swift \
    App/AdventureGame.swift App/AdventureWalkPath.swift App/AdventurePosture.swift \
    "Tests/$adventure_suite.swift" -o "$adventure_checks_dir/$adventure_suite"
  "$adventure_checks_dir/$adventure_suite" \
    App/Resources/Qingming/story.json App/Resources/World/world.json
done
```

- `AdventureModelChecks`: **208 checks**. Remapped mission order, all unique quest seals and bilingual two-line poems, crossing detection, no rewards on arrival, challenge dismissal/re-entry, reward idempotency, coins and gear, fold-only soy delivery, persistent exact resume, pause behavior, Pro/path/wardrobe gates, new path starts, and both story branches.
- `AdventurePostureChecks`: **62 checks**. All five discrete poses, no duplicate events from identical samples, letters and Mother's scene-specific replies, saved letters, backward-compatible optional fields, both endings, and letters never duplicating mission rewards.
- `AdventurePathAndCricketChecks`: **1,129 checks**. All 44 Catmull–Rom road points, smooth joins, 1,001 finite samples, endpoint clamps, validation and local override persistence, export schema, unchanged source JSON, exact feet placement, Capital-only cricket, valid winners, five-copper rewards, persistent match deduplication, and rematches.
- `AdventureWorldChecks`: **574 checks**. All named places and latest geometry, geometry-fingerprinted save/path migration, preserving earned progress while moving old-world positions to the new home once, exact fold/unfold resume even after every local quest is complete, no skipped paper boat or pending delivery, backtracking protection, no encounter teleporting, mist fades/speed boost at the latest seams, scene arrival signals, both updated routes, and byte-for-byte unchanged source JSON.
- `AdventureDepartureChecks`: **197 checks**. A visible one-time 1.44-second walk out of Home, continuous leftward movement with feet on the road on every frame, waiting with a hint, manual takeover, persisted introduction state, and five consecutive fold/reopen cycles retaining the exact hero coordinate.

The original four model suites accept optional arguments: first the story JSON path, then the World JSON path. Departure checks use the same portable repository-relative paths shown above.

## World coordinates

```sh
seeker_coordinates_dir=$(mktemp -d /tmp/scroll-seeker-coordinates.XXXXXX)
xcrun swiftc -swift-version 6 \
  App/ScrollArchive.swift App/ScrollViewportMath.swift \
  App/AdventureArchive.swift App/AdventureWorldArchive.swift App/AdventureWalkPath.swift \
  Tests/SeekerCoordinateChecks.swift -o "$seeker_coordinates_dir/coordinate-checks"
"$seeker_coordinates_dir/coordinate-checks" \
  App/Resources/World/world.json App/Resources/Qingming/story.json
```

**3,110 checks** cover all 17 current mission positions across 5 viewport sizes and 7 zoom levels: exact image aspect ratio, right-edge offsets, reversible coordinates, viewport/minimap coverage, pinch anchoring, vertical reachability through 6× zoom, and transient zero-size layouts. Coordinate arguments are World JSON first, story JSON second.

## Paper-boat folding

```sh
origami_checks_dir=$(mktemp -d /tmp/scroll-origami-checks.XXXXXX)
xcrun swiftc -swift-version 6 \
  App/AdventurePosture.swift App/AdventureOrigamiState.swift \
  Tests/AdventureOrigamiChecks.swift -o "$origami_checks_dir/origami-checks"
"$origami_checks_dir/origami-checks"
```

**35 checks** exercise the discrete origami posture sequence without timers or a simulator. A physical half-fold accepts Book or Laptop orientation.

## On-device poem validation and caching

On the supplied Apple-silicon macOS 27 host with the iOS 27.1 toolchain:

```sh
poem_checks_dir=$(mktemp -d /tmp/scroll-poem-checks.XXXXXX)
xcrun swiftc -swift-version 6 -target arm64-apple-macos26.0 \
  App/ScrollArchive.swift App/AdventureArchive.swift \
  App/AdventureWorldArchive.swift App/AdventureWalkPath.swift \
  App/AdventurePoemStore.swift Tests/AdventurePoemChecks.swift \
  -o "$poem_checks_dir/poem-checks"
"$poem_checks_dir/poem-checks" App/Resources/Qingming/story.json App/Resources/World/world.json
```

**44 checks** validate exact two-line poems, whitespace and CRLF handling, blank/extra-line rejection, length limits, all 17 curated fallbacks, cached generated poems, and corrupt-cache recovery. No model generation or real player saves are used.

Core suites above: **5,359 checks**.

## Seamless world tiles

```sh
tile_checks_dir=$(mktemp -d /tmp/scroll-world-tiles.XXXXXX)
xcrun swiftc -swift-version 6 \
  App/WorldTileManifest.swift Tests/WorldTileChecks.swift \
  -o "$tile_checks_dir/tile-checks"
"$tile_checks_dir/tile-checks" App/Resources/World/tiles/tiles.json
xcrun swiftc -O -swift-version 6 \
  App/WorldTileManifest.swift Tests/WorldTileArtChecks.swift \
  -o "$tile_checks_dir/tile-art-checks"
"$tile_checks_dir/tile-art-checks" App/Resources/World/tiles/tiles.json
```

**2,259 layout checks** cover three display densities, five screen heights, six zoom levels, shared pixel-rounded boundaries, exactly one physical pixel of overdraw, no cumulative gaps, a shorter final tile, and malformed manifests.

**13 artwork checks** use ImageIO to verify the actual source and all six tile dimensions and compare 29,322 RGB samples at both sides of every seam against the matching `world.jpg` pixels. The supplied 9,832 × 724 art averages **1.553/255** RGB difference (expected independent JPEG recompression), confirming the tiles belong at their exact declared offsets. Six eager decodes and comparisons took approximately 0.031 seconds on the development Mac; this is not an iPhone frame-rate measurement. No artwork is written or regenerated.

## Continuous hero camera

```sh
camera_checks_dir=$(mktemp -d /tmp/scroll-camera-checks.XXXXXX)
xcrun swiftc -swift-version 6 \
  App/ScrollHeroCamera.swift Tests/ScrollHeroCameraChecks.swift \
  -o "$camera_checks_dir/camera-checks"
"$camera_checks_dir/camera-checks"
```

**4,423 checks** cover five consecutive right-to-left opening glides, a mid-animation Duo resize during each opening (preserving phase with newly computed bounds), a complete journey with the hero kept visible, clamped offsets without empty canvas, post-opening geometry changes anchored on the hero, and Reduce Motion.

Total for these suites: **12,054 checks**. UI playability, physical posture events, presentation transitions, and purchase flows still require simulator/device verification. The exact implemented route and fallback posture sequence are in [Demo walkthrough](../docs/Demo.md).
