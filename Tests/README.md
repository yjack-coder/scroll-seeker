# Scroll Seeker model checks

These 47 checks compile the production `ScrollArchive` and `SeekerGame` on macOS using Foundation and Observation. They need no simulator, test target, RevenueCat, or project configuration changes. Run from the repository root with Swift 6:

```sh
seeker_checks_dir=$(mktemp -d /tmp/scroll-seeker-checks.XXXXXX)
swiftc -swift-version 6 \
  App/ScrollArchive.swift \
  App/SeekerGame.swift \
  Tests/SeekerModelChecks.swift \
  -o "$seeker_checks_dir/model-checks"
"$seeker_checks_dir/model-checks" App/Resources/Qingming/targets.json
```

The executable accepts the path to a `targets.json` file as its first argument. If omitted, it uses `App/Resources/Qingming/targets.json` relative to the current directory. Successful execution prints `Passed 47 Scroll Seeker model checks`. No app files or real player defaults are changed: each run uses a unique UserDefaults suite that is removed after completion.

Checks cover the supplied archive, right-to-left progression, bilingual names, elliptical normalized hit testing and overlap resolution, duplicate and out-of-order finds, persistent free-hint limits, unlimited Pro hints, progress reload, active-search timing with an injected clock, pauses, independent chapters, museum collection, and chapter completion. These are model checks; UI interactions and real payment behavior require separate simulator or device verification.
