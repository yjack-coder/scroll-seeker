# Xiao An character sprites

Three generated, transparent PNG sprites live in `App/Resources/Qingming/Characters/`:

- `xiao_an_child.png`
- `xiao_an_scholar.png`
- `xiao_an_thief.png`

Each is 1,024 × 1,536 RGBA. The images were generated specifically for the requested hero, not downloaded. The historic panorama and clue crops remain unchanged. The app downsamples the sprites, scales them with the painting, and anchors their measured feet to the walking spline. Walking subtly compresses the figure around that anchor; it does not bob his feet away from the road. The console's explicit Jump action is a separate animation.

## Generation prompt

Shared prompt, used for each look:

> Create a production-ready 2D character sprite for a quiet story adventure inside Zhang Zeduan's Along the River During the Qingming Festival. Transparent alpha background, one isolated full-body Chinese male character ONLY. No scenery, no ground, no text, no frame, no checkerboard, no colored backdrop. Song dynasty gongbi painting: fine warm-black ink outlines, mineral pigment flat washes, muted indigo, ochre and warm cream, subtle silk-like brush texture only within the figure. NOT cartoon, not chibi, not cute mascot, not 3D, not photorealism. Facing LEFT in a readable three-quarter side profile, feet visible, relaxed mid-stride walking pose, arms naturally at sides. Entire body fits the canvas with tight clean transparent margins; painted silhouette should occupy 85 percent of image height. Gentle soft warm outline hugging the figure for visibility on an aged painting. Portrait sprite composition.

Child addition:

> Xiao An, a small Chinese boy around nine years old, earnest calm face, dark hair in a small traditional topknot, simple cream linen tunic with worn indigo vest, brown belt and straw sandals. Carries an empty small ceramic bottle tied at his waist. Child proportions realistic, not exaggerated.

Scholar addition:

> Xiao An as a young Chinese scholar around twenty, calm earnest face, dark hair under a simple Song dynasty black scholar cap, warm cream long scholar robe with restrained muted indigo trim, cloth boots, a small rolled manuscript tucked at his belt. Slim graceful adult proportions.

Thief addition:

> Xiao An as a young Chinese gentleman thief around twenty, the same calm earnest face and slim build, dark hair tied neatly, dark charcoal-indigo cloak over practical muted brown Song dynasty clothes and cloth boots. Face visible, no mask, no weapons. Robin Hood-like compassionate resolve, historically grounded and understated.

These are single-frame painted sprites with a lightweight SwiftUI walking treatment, not a frame-by-frame walk cycle. There is no runtime image-generation dependency.
