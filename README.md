# 尋畫 Scroll Seeker

A hidden-object game inside Zhang Zeduan’s Qingming handscroll, built for iPhone and iPhone Duo.

## Play

- Choose The River (free) or The City (Pro). Each contains five supplied historical clues.
- Fold for a brass-framed clue. Unfold to search. The toolbar’s **Open / Folded** button replays the transition in the simulator.
- The eight original tiles form one continuous, 25,609 × 1,200 painting in a zero-spacing `LazyHStack`. Always enter at the right-hand countryside; pan left toward the city. Pinch from 1× to 4× and pan vertically when enlarged.
- Discovery blooms warmth and saturation on the original painting pixels. Gold rings, red seals, and a story follow. Wrong taps carry no penalty.
- Generated colorizations appear **only in story cards**, labeled “The scene come to life.” They never overlay the historic painting. [Prompts and asset provenance](docs/Colorization.md).
- Completed chapters awaken right-to-left. Optional synthesized paper and guqin-like sounds are in Settings; sound defaults off and respects Silent mode.
- One free hint per chapter; Pro unlocks unlimited hints and Museum Mode for revisiting earned stories.

## Fold and accessibility

iOS 27.1’s continuous hinge angle drives the reveal when available, with an animated posture/size-change fallback. Flexible layouts accommodate the Duo’s outer and inner displays. Named painting accessibility actions provide zoom, pan, and inspect-center controls. Reduce Motion removes continuous atmospheric movement and uses immediate reveals. Timing pauses outside active searching.

## RevenueCat

The connected account’s existing `pro` entitlement, `default` offering, and [published paywall](https://app.revenuecat.com/projects/34a58452/paywalls/pwc4af656faf734819/builder) are reused. Paywall revision 5 is styled for Scroll Seeker. Existing product IDs and prices are preserved, as requested when a catalog already exists:

| Package | Existing USD price |
| --- | --- |
| Monthly | $3.99 |
| Yearly | $24.99 |
| Lifetime | $49.99 |

RevenueCat and RevenueCatUI remain pinned to 5.80.0: the connected SDK endpoint returned the complete published paywall for this version during verification. Debug/simulator builds use RevenueCat Test Store with real SDK entitlement checks, not a local Pro bypass. Test Store purchases do not charge money. Restore and Customer Center are available in Settings.

Live App Store billing still requires App Store products/credentials and the public `appl_…` SDK key as `RevenueCatAPIKey` in Project.json. Release builds exclude the Test Store key and safely leave The River available until live billing is configured. No secret keys belong in the app.

## Assets, storage, and verification

Original tiles, target JSON, and clue crops were copied from the supplied `/Users/jackzhao/Desktop/qingming` folder without alteration. No replacement panorama or overview image was generated or downloaded. Only the ten explicitly requested clue colorizations were generated.

Progress, earned seals, hint counts, chapter times, and sound preference persist locally. Existing Liubai journal data is left untouched; obsolete journal implementation files were removed and remain recoverable in git. No microphone/speech permission is requested. No CloudKit synchronization is implemented.

Verification includes 47 native model checks (reading order, target detection, persistence, hint limits, timers) and 1,334 coordinate checks across supplied targets, viewport sizes, and zoom levels. Build and UI checks use Bitrig’s iPhone Duo simulator.

Zhang Zeduan, Along the River During the Qingming Festival, Northern Song. Public domain.
