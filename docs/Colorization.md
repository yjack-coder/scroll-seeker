# Scroll Seeker colorized story images

Mode: built-in `image_gen` tool, **edit**. Each local source crop was inspected before its edit. The nine edits in this batch each used their corresponding file from `App/Resources/Qingming/clues/` as the sole edit target. The existing approved donkey edit was copied into the same destination directory. The original JPEG clue crops and all panorama tiles remain unchanged.

## Usage constraint

These are AI-assisted, historically inspired color interpretations for the story-card section **“The scene come to life”** only. They are not historical color reconstructions and are not geometrically registered to the original painting. Inspection found that generated line work and small details can drift. **Never overlay these images on the panorama or use them for target placement, hit testing, or the search clue.** Search uses the original supplied images and coordinates.

The built-in tool returned 1254 × 1254 PNG images for all ten scenes. All selected final assets are copied into the app workspace; the app must not reference the generation-cache paths.

## Final prompt for the nine edits

```text
Use case: style-transfer
Asset type: color-reveal layer for a hidden-object game using an authentic public-domain Chinese handscroll.
Input image 1: edit target. This is a close crop of Zhang Zeduan's Along the River During the Qingming Festival.
Primary request: Colorize this exact image with luminous traditional Chinese mineral pigments: azurite blue, malachite green, cinnabar red, ochre, warm gold. Add vivid but tasteful historically inspired color within the existing ink contours, like hand-painted pigments on silk. Retain visible aged silk weave and every original black ink line and worn mark. Keep the silk ground warm antique parchment.
Constraints: CHANGE ONLY COLOR. Preserve EXACT composition, framing, geometry, perspective, all positions and proportions of people, animals, vessels, architecture, ropes and objects. Do not redraw, move, add, remove or reinterpret anything. Do not crop, rotate, warp, zoom, sharpen into a modern illustration, or replace the background. No new text, labels, borders, seals, watermark or glow. Preserve any existing writing exactly. Flat painterly mineral pigments, no photorealism, no 3D. Return the same full square composition so it can register over the source.
Specific source asset: {id}. Preserve the exact visible subject and its details from this input.
```

The `{id}` placeholder was replaced separately with each target identifier in the table below. The donkey was an earlier approved edit; its original tool result is recorded separately.

## Saved assets

| Target | Final workspace path | Generated source |
| --- | --- | --- |
| donkeys | `App/Resources/Qingming/colorized/donkeys_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df3b-6916-75b1-8542-e637eb69aa3e/exec-65ac2f49-3726-4251-82c1-b4a2c33d669a.png` |
| cargo_boat | `App/Resources/Qingming/colorized/cargo_boat_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-fce65e92-3d0e-42c1-9338-1436558b3e11.png` |
| city_gate | `App/Resources/Qingming/colorized/city_gate_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-b65309a4-0513-43af-9270-0e1dad9b0792.png` |
| ox_cart | `App/Resources/Qingming/colorized/ox_cart_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-95a0bfa1-ff5e-47e5-b88a-b4041d9568ea.png` |
| scaffold_tower | `App/Resources/Qingming/colorized/scaffold_tower_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-dbe7143a-810b-4b85-b5b2-d0e59b5fca54.png` |
| camels | `App/Resources/Qingming/colorized/camels_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-613db431-c4ca-494c-a12d-10eadf1a835f.png` |
| sedan_chair | `App/Resources/Qingming/colorized/sedan_chair_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-dd89f0b4-939b-4a8f-a0eb-cbeccb11688d.png` |
| rainbow_bridge | `App/Resources/Qingming/colorized/rainbow_bridge_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-6170f42f-39be-4efe-a650-7001e47ffbf0.png` |
| sailboat | `App/Resources/Qingming/colorized/sailboat_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-0be50770-edcc-42f3-b58f-a83dac251cf3.png` |
| wine_shop_sign | `App/Resources/Qingming/colorized/wine_shop_sign_color.png` | `/Users/jackzhao/.codex/generated_images/01a0df61-6620-7f60-9381-2dba5cdb847b/exec-a968a5d5-674c-41fa-8d27-e8e126bc1819.png` |

Source painting: Zhang Zeduan, *Along the River During the Qingming Festival*, Northern Song. Public domain. Generated pigments are an artistic interpretation.

