# 留白 Liubai

A private, offline-first ink-wash journal for iPhone and iPhone Duo.

Write a short reflection, then open the scroll. Canvas builds a deterministic landscape from emotional weight, flow, and uncertainty. On supported devices, Foundation Models supplies structured interpretation and a bilingual poem. Offline keyword interpretation and six original poems cover simulator use and unavailable models. Ten dated studio samples are installed once; they are clearly identified and never consume the daily free painting.

## Try it

- Use the Open / Folded toolbar action to replay the scroll on any simulator.
- iPhone Duo's iOS 27.1 hinge angle drives the paper reveal. Native navigation and flexible content adapt to its two displays. Physical fold controls are in Bitrig beside the simulator.
- Tap a painting to read its source reflection and poem in accessible text.
- The Long Scroll includes seven calendar days for Free and 365 days for Pro.
- Pro also unlocks manual seasonal styles, drawn calligraphy with a seal, and a six-second MP4 unroll export using the native share sheet.
- Dictation appears only when on-device speech recognition is supported.

## Purchases

RevenueCat project: [留白 Liubai](https://app.revenuecat.com/projects/34a58452). The [published paywall](https://app.revenuecat.com/projects/34a58452/paywalls/pwc4af656faf734819/builder) is revision 3, with a compact layout for short displays.

The `pro` entitlement is served by current offering `default`:

Purchases and RevenueCatUI are pinned to 5.80.0. At verification time, the connected project's SDK endpoint returned an empty published paywall component payload to 5.86–5.91, while 5.80.0 received the complete published design. Upgrade only after confirming that the published design loads through `PaywallView`.

| Package | USD price |
| --- | --- |
| Monthly | $3.99 |
| Yearly | $24.99 |
| Lifetime | $49.99 |

Simulator and debug builds use RevenueCat Test Store. Its purchase outcomes are simulated and never charge money. The app gates access using actual RevenueCat customer information; it has no local Pro override. Restore purchases and Customer Center are available in Settings.

Before shipping live billing, connect App Store products and credentials and supply the App Store public SDK key (`appl_…`) as `RevenueCatAPIKey` in Project.json's Info.plist properties. Device release builds deliberately exclude the Test Store key and show an unavailable-purchases message until live billing is configured. Never put a RevenueCat secret key in the app.

## Storage and privacy

Reflections, deterministic landscape parameters, and poems are encoded locally in UserDefaults. Draft text is also retained locally. No journal text is sent to RevenueCat or an external AI service. RevenueCat receives the anonymous purchase data needed to manage membership. Video export is local and shared only through the system share sheet.

Deleting the app removes its local journal. This version does not provide iCloud synchronization.

Project configuration is managed by Bitrig in `Project.json`. Build and run with Bitrig.

## Verification

- Bitrig simulator build succeeds with no diagnostics.
- 44 isolated native model checks passed: bilingual emotional mapping, normalized parameters, deterministic seeds, four-line poems, persistence, samples, free/Pro date windows, daily allowance, and concurrent generation suppression.
- On the Duo simulator, writing and persistence, fold/open replay, source words, full history, synthetic yearly purchase, restore, Customer Center, and privacy navigation were exercised.
- The actual Canvas painting rendered successfully into a six-second MP4, with the final frame inspected and the native share sheet opened without sending it.
- Themed RevenueCat PaywallView rendering was verified after pinning the compatible SDK. The physical hinge-angle path is SDK-verified; simulator fold changes remain controlled by Bitrig's Fold controls.
