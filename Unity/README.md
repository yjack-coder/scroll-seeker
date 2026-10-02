# Scroll Seeker — A Life Along the River (3D)

A desktop adventure about Xiao An's small promise: leave the farmhouse, cross Willow Bridge, buy and fill a bottle of soy sauce, then walk home and deliver it to Mother. The Unity project is independent of the original Swift/iOS game in `App/`.

## Play

Open `Assets/ScrollSeeker/Scenes/Riverside.unity` and press Play. The scene's `GameSession` constructs a deterministic riverside village at startup, including characters, buildings, trees, boats, the river, the bridge and collision surfaces. The two riverbanks are connected by a walkable bridge. Red awnings, lanterns and seals mark places and objects worth approaching.

1. Walk beside Mother outside the west-bank farmhouse. Press **E**, then **E** again to accept her errand.
2. Follow the path east across Willow Bridge to Master Chen's red awning.
3. Speak to the merchant and buy the bottle for **4 copper**. The journey starts with 10 copper.
4. Choose **Laptop (5)** at the counter and interact again. Use A/D, arrow keys or the slider to keep the red marker inside the moving jade band for three seconds. Wandering to the shop or opening the posture alone does not fill the bottle.
5. Choose **Open (1)** and walk back across the bridge. Beside Mother, choose **Folded (2)** and click **Deliver soy sauce**. Delivery consumes the bottle and awards **8 copper** plus the homecoming seal once.
6. Explore for three collectible ink seals, worth one copper each. Consult the Book map or replay earned memories in the Tent theater.

The bottle purchase, timed challenge, interaction distance and Folded delivery are checked by gameplay rules. Ordinary posture changes preserve world position. There is no remote delivery or travel shortcut.

## Controls and postures

| Input | Action |
| --- | --- |
| WASD / arrow keys | Move relative to the camera |
| Left Shift | Run |
| Hold right mouse button | Orbit camera |
| Mouse wheel | Zoom camera |
| E / interaction button | Speak, collect, confirm |
| 1 · Open | Explore the full 3D scene |
| 2 · Folded | Pause, read the home letter, deliver beside Mother |
| 3 · Book | Pause, inspect two-page quest journal and live map |
| 4 · Tent | Pause, present only earned memories as animated shadow puppets |
| 5 · Laptop | Explore with the counter desk; pour at the merchant |
| Escape | Close dialogue/challenge or return to Open |
| F5 | Save position and progress |
| M | Toggle the generated interaction chime; off by default |

These are desktop gameplay modes selected with keys or buttons. Real hinge sensors and physical folding hardware are not implemented in this version.

## Editor and build

Use **Unity 6.3 LTS, 6000.3.25f1, Apple Silicon**. Unity Hub manages the installation and license. The macOS Mono player support comes with the editor; this project does not need Android, Web, Windows, iOS or IL2CPP modules for the supplied Mac build. A Unity account and suitable Unity license are required for the editor. No paid assets are used.

1. In Unity Hub, add the `Unity/` directory as a project and select the pinned editor.
2. Open the Riverside scene. If regenerating the checked-in scene/settings, choose **Scroll Seeker → Prepare playable scene**.
3. Press Play. Choose **Scroll Seeker → Build macOS demo** to build `Builds/Scroll Seeker.app`.

Double-click the supplied `Scroll Seeker.app` in Finder to play without opening the editor. For a local build, run `open 'Builds/Scroll Seeker.app'` from the Unity project directory. The supplied development build opens a fresh journey through the ordinary save location; verification saves are isolated from it.

The supplied build is a windowed macOS Universal development build (ARM64 and x86_64) using Metal and Mono. It was run natively on Apple Silicon; Intel execution has not been verified. Development diagnostics support the explicitly requested smoke check below. Normal startup never runs the smoke check. Distribution signing, notarization, Windows and Unity iOS builds are outside the current verified target.

The package manifest pins the Unity Test Framework. Generated Library, logs, local builds and user settings are excluded from Git; source, scene, package lock and ProjectSettings are tracked.

## Modules

| Directory | Responsibility |
| --- | --- |
| `Core/Journey.cs` | Pure ordered quest transitions, inventory, posture delivery gate, unique seal/reward rules, validated state |
| `Core/SaveStore.cs` | Versioned JSON, state validation, atomic primary replacement, last-good backup recovery and IO warnings |
| `Gameplay/GameSession.cs` | Distance-gated interactions, challenge timing, autosave, keyboard posture input and orchestration |
| `Gameplay/ThirdPersonMotor.cs` | Camera-relative controller movement, gravity, grounded collision and fall recovery |
| `Gameplay/OrbitCamera.cs` | Mouse orbit, zoom limits and obstacle avoidance |
| `Gameplay/InkCharacter.cs` | Procedural limb gait and idle head motion |
| `World/` and `Shaders/` | Deterministic generated village geometry, materials, lighting and fog |
| `UI/ScrollHUD.cs` | Resolution-scaled parchment UI, inventory, dialogue, journal, theater and pouring feedback |
| `Editor/ProjectBuilder.cs` | Reproducible scene/settings preparation and Mac build |
| `Tests/` | Model/storage NUnit checks and scene PlayMode checks |

The character is a stylized procedural puppet with a transform-based walk/run gait and idle animation. No motion capture, imported skeletal rig or purchased character pack is included.

## Saves

Unity stores its own `journey-v1.json` under `Application.persistentDataPath` (macOS: `~/Library/Application Support/Scroll Seeker/Scroll Seeker — A Life Along the River/`). It never reads or writes the Swift game's UserDefaults. F5, gameplay transitions, an eight-second interval and application exit save progress and exact position. A damaged primary falls back to the last-good `.bak`; invalid or unknown-version saves start a fresh journey and show a warning. Rewards remain unique after reload. Copper is capped at 10,000.

To demonstrate a fresh journey without disturbing an existing save, launch the executable with a separate absolute `-seekerSavePath /path/to/demo/journey.json` argument. There is no cloud synchronization.

## Tests and route verification

Run **Window → General → Test Runner**. EditMode covers quest sequencing, inventory/reward consistency, distance-independent delivery rules, idempotency, invalid state, exact JSON roundtrips, backup recovery, unknown versions and real filesystem failure paths. PlayMode constructs an isolated scene and checks remote interaction rejection, posture pausing, the merchant challenge gate and physically walking across the bridge.

From a shell, with the editor closed:

```sh
UNITY_EDITOR='/Applications/Unity/Hub/Editor/6000.3.25f1/Unity.app/Contents/MacOS/Unity' Unity/Tools/check-and-build.sh
```

`SCROLL_SEEKER_RESULTS` changes the report destination; `SCROLL_SEEKER_BUILD` changes the `.app` output path. See `Tools/check-and-build.sh` for the exact commands. Do not add `-quit` to `-runTests`; the test runner exits after completion.

An opt-in development-player route check walks continuously through the real controller and collisions, invokes the ordinary interaction/challenge methods, and captures nine screenshots. It uses a fresh isolated save, checks blocked remote delivery and repeated rewards, then reloads the final save from disk:

```sh
'Builds/Scroll Seeker.app/Contents/MacOS/Scroll Seeker — A Life Along the River' \
  -seekerSmokeTest -seekerSavePath /absolute/path/to/new-verification/journey.json \
  -logFile /absolute/path/to/new-verification/player.log
```

The verification save must not already exist. This driver supplies movement directions and follows the pouring target; it tests game behavior and rendering, while manual keyboard/mouse play checks cover input usability separately. Actual results and limitations are recorded in `../docs/UnityValidation.md`.

## Sources and scope

See [asset provenance](ASSET_SOURCES.md) and [environment/install notes](../docs/DevelopmentEnvironment.md). The Unity slice contains one complete errand and optional seals. The original game's other missions, adult paths, wardrobe, RevenueCat purchases and local poem generation remain in the Swift project and are not ported here.
