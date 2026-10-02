# Unity asset provenance

No Asset Store purchases, downloaded model packs, external texture libraries or generated image files are used in the Unity slice.

| Asset | Source and rights |
| --- | --- |
| Village buildings, bridge, boats, trees, rocks, river and mountains | Geometry authored procedurally in this repository's `World` C# sources |
| Xiao An, Mother, Master Chen and the river elder | Repository-generated character geometry, with a procedural limb gait |
| Ink-wash surface and water look | Repository shader source and mathematical texture/color variation |
| HUD rice paper, seal discs and shadow puppets | Repository-generated textures and shapes in `ScrollHUD.cs` |
| Interaction chime | Repository-generated decaying sine waveform in `GameSession.cs` |
| HUD typography | Locally available Georgia/Helvetica Neue or fallback OS fonts, loaded through Unity's dynamic OS font API; font files are not copied into the project |
| World signboard typography | Unity's bundled `LegacyRuntime.ttf`, used through its built-in font API; no external font files are copied |
| Unity engine/modules and NUnit test framework | Official Unity editor/package registry; their upstream terms and bundled third-party notices apply |

The visual direction, characters, five posture names and soy-sauce errand continue the existing Scroll Seeker design. The Unity world does not copy the supplied iOS painting or historical artwork into a 3D texture. Existing iOS artwork/source records are retained unchanged in `docs/Colorization.md` and `docs/CharacterSprites.md`.

The repository had no root LICENSE file at the start of this extension. This record does not grant new rights to the existing artwork, trademarks or repository as a whole; those retain their existing ownership and attribution. No license is invented for third-party material.
