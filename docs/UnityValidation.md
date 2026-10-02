# Unity validation

Validation date: 2026-10-02. Target machine: Apple M5 MacBook Pro, macOS 27.0, 24 GB memory. Target editor: Unity 6000.3.25f1 ARM64.

## Original iOS regression

The original Swift production models were compiled with Swift 6 using the documented source set, and run against `App/Resources/Qingming/story.json` and `App/Resources/World/world.json`:

| Suite | Passed checks |
| --- | ---: |
| AdventureModelChecks | 208 |
| AdventurePostureChecks | 62 |
| AdventurePathAndCricketChecks | 1,129 |
| AdventureWorldChecks | 574 |
| AdventureDepartureChecks | 197 |
| Total | 2,170 |

These validate model behavior. The iOS app UI, store billing and physical fold hardware were not rerun or newly verified in this extension. Original Swift code and artwork were retained.

## Unity results

| Check | Actual result |
| --- | --- |
| Unity editor compilation and scene preparation | Passed in 6000.3.25f1 |
| EditMode | 115 passed, 0 failed |
| PlayMode | 8 passed, 0 failed |
| macOS development build | Succeeded; approximately 294 MiB |
| Standalone complete errand | 19 runtime checks passed; process exited 0 |
| Save after delivery and seal collection | Reloaded Complete stage, 15 copper and unique claimed reward |
| Actual renderer screenshots | Nine 1440 × 900 captures, reviewed for scene and HUD issues |

The build contains ARM64 and x86_64 slices, verified with `lipo -archs` on both the player executable and UnityPlayer. Execution was verified on this M5 Mac; Intel execution was not tested. The build uses Metal and Mono.

EditMode tests cover ordered transitions, invalid saves, atomic replacement, recovery, inventory consistency and repeat-reward prevention. A scene serialization regression checks the actual checked-in Riverside asset. PlayMode checks startup movement, immediate dialogue pause, read-only posture interaction rejection, merchant proximity, repeated-interaction challenge protection and continuous physical bridge traversal.

Verification found and fixed a controller dead zone at very small frame intervals, empty serialized dialogue falsely pausing startup, repeated interaction restarting the pour, GUI color-space mismatch, scaled shadow-puppet segments and overflowing sign text. These findings were checked in the actual editor/player rather than inferred from source compilation. Runtime logs and XML reports are supplied in the delivery's `verification/` folder.

## Verification scope

The development-player route driver uses an isolated save, moves the actual CharacterController along the village lane and bridge in both directions, triggers ordinary dialogue/purchase methods, follows the live pouring target for the real challenge timer, walks home and delivers in Folded. It checks remote-delivery rejection, unique rewards and final disk reload. Its supplied movement and pouring input must be distinguished from a human keyboard/mouse playthrough.

Screenshots are captured from the actual standalone Unity renderer with the game HUD. The procedural world is assembled at runtime from the checked-in Riverside scene, rather than stored as a large serialized mesh scene.

The Mac was locked during the final native UI check. Manual keyboard/mouse usability remains unverified; the complete task traversal and screenshots above were produced by the real-player route driver. Keyboard bindings and UI click paths are implemented, but they must be distinguished from that automated movement/pouring evidence.

## Limits

Only macOS Apple Silicon execution was verified. Distribution signing/notarization, Intel execution, Windows, Unity iOS, real folding hardware, gamepad, voice, cloud saves and a complete port of all native missions are outside this slice. The new 3D character has procedural walk/run/idle motion and a simple generated model. The original native payment integration is not included in Unity.
