# Scroll Seeker — demo route

This is the click path implemented by the app, not a claim that every step has been observed on physical hardware. Native regression checks prove model progression, rewards, exact fold/resume positions, and the origami state machine. Simulator observations are reported separately in the handoff.

## Start and movement

Launch into **Home / Folded**. Existing saves keep their earned progress; a fresh adventure starts at the right-hand house. Select **Open** in the toolbar, tap **展卷出門 / Unfold to continue your journey**, or physically unfold. On first departure Xiao An walks left a few steps, then waits with the movement hint. Hold the left half to walk left, the right half to walk right, or tap the road. The camera follows him. Release to stop. Do not tap objects to complete quests: walking near the next marked person opens the dialogue.

For a repeat-reveal check: **Open → Home corner button → wait for the letter and roll-up → Open**, five times. Position and completed quests must not change. Reopening later never jumps back to Home or skips to another scene.

On every quest dialogue, scroll down if needed and tap **Lend a hand / 我來幫忙**. After winning, tap **Continue the story / 故事繼續**, wait for the local color bloom, then tap **Continue the story** on the seal/poem reward card.

## Act I: the soy-sauce errand

| Order | Posture | Exact interaction |
| --- | --- | --- |
| 1. 驢隊迷路 / Donkeys | Open; Laptop optional | Walk left from Home. In the challenge tap **Donkey 1**, then **Caravan place 1**; repeat for 2 and 3. Drag-and-drop also works. Laptop moves the controls to the lower deck. |
| 2. 問路 / Directions | Open | Continue left. Choose **勞駕，請問往汴河怎麼走？ / Excuse me, which path leads to the Bian River?** |
| 3. 紙船 / Paper boat | Open → Book → Open, with rotations | Use **Fold → Unfold → Rotate 90° → Fold → Unfold → Rotate back → Fold → Unfold**. These eight on-screen actions are the reliable simulator route. Physical half-fold accepts Book or Laptop after rotating. Wait for the boat to float away. |
| 4. 拉縴 / Boatmen | Open; Laptop optional | Continue left. Tap **拉！ / PULL** once while the marker is in gold on each of three separate beats. **Slower timing** gives a generous window. Do not tap three times during the same beat. |
| 5. 虹橋驚魂 / Rainbow Bridge | Start Open, change to Book | Continue left. Wait until **HALF-FOLD NOW** appears, then tap **半摺 / Half-fold** or switch to Book. Wait for the boat to pass. An early fold requires **Open before half-folding**; a bump offers **Try again**. After the reward, choose **Open** in the posture control to leave memory view and resume walking. |
| 6. 打醬油 / Soy sauce | Open | Continue left. Choose **May we agree on a fair price for a full bottle?** Then adjust the balance slider opposite the indicated lean; keep the marker in the gold center until the counter reaches three seconds. It is a slider control, not physical tilt. |
| 7. 回家 / Deliver | Folded | Use the Home corner button or physically fold. Wait for the letter. Tap **Give Mother the bottle / 把醬油交給娘**, then **Continue the story**. Collect the seal and view the Act I ending. **Tent theater** is an optional mirrored shadow-puppet presentation. Tap **See where life leads**. |

## Fork and RevenueCat Test Store

After Act I, the world resumes at the saved soy-shop position. Walk **right** back toward Rainbow Bridge, or return Home and tap **人生岔路 / Return to the fork**. Select **Open like a book** (Book posture) to reveal the two future pages.

1. On a customer without `pro`, tap the left **Scholar** or right **Gentleman Thief** page.
2. The existing RevenueCat `PaywallView` appears. Select the desired plan and its purchase button.
3. In RevenueCat's **Test Store** dialog choose **Successful Purchase**. No real payment is made in this simulator build.
4. The SDK-confirmed `pro` entitlement dismisses the paywall. The chosen page expands, posture returns to **Open**, and the selected Act II path becomes playable.
5. To test cancellation, close the paywall before purchase: both adult paths remain locked. Home **Settings → Restore purchases** and **Customer Center** use the existing RevenueCat integration.

If Settings already shows Pro, the fork correctly opens the chosen path without another paywall. Test Store purchase history persists independently of story saves. Do not delete app data or revoke purchases merely to manufacture a paywall demo. A genuinely fresh test customer is needed to re-test a first purchase.

## Act II: Scholar

Keep **Open** between encounters and walk left from the tea house.

1. Tea house couplets: choose **細雨潤書窗 / Gentle rain softens the study window**, then **水清映月光 / Clear water mirrors moonlight**.
2. City gate: choose **I have come for the examination. Here are my papers.**
3. Ink merchant: choose **The one whose test stroke stays clear, even in a fine line.**
4. Poetry tower couplets: choose **千帆過半城 / A thousand sails pass half the city**, then **酒巷起春風 / The tavern lane welcomes spring wind**.
5. The exam is at the same tower: begin walking briefly to trigger its next dialogue. Answer **Five**, **Clear water mirrors moonlight**, **Protect the book and keep the promise**; use **Next question** between answers, then **Prepare the paper**.
6. Tap **Fold to submit** (**Folded**): the sealed paper remains on the outer screen with **Grading…**. Tap **Unfold the results** (**Open**), then **Accept the result** to earn Top Scholar. Incorrect first choices offer a penalty-free retake; the final quest requires all three correct.

## Act II: Gentleman Thief

Start **Open** at the grain barge. On stealth challenges, tap **Hide · Tent**, wait for **LOOKING AWAY**, tap **Unfold · Move**, then hold **HOLD TO MOVE** or tap **Take one quiet step**. Hide again before the lantern turns back. Checkpoints preserve progress, and there is no coin penalty. Each stealth quest requires hiding at least once.

Proceed left: **grain barge → city gate → barrel/ox cart → tavern**. At the tavern tap **TAKE THE PURSE** while the marker is gold (Slower timing is available). The final escape is back at the city gate: walk **right**, then finish the same hide/open stealth sequence. The optional Tent puppet theater can present earned endings.

## Important limits and demo pitfalls

- The simulator's physical fold control must be operated by the person using Bitrig; app buttons/pickers provide equivalent discrete gameplay events. Tent cannot be reliably distinguished by the SDK's three hinge statuses, so use its on-screen fallback.
- **Book** outside a mission is memory view and pauses walking; choose **Open** to continue. Fully folding an unfinished non-exam mission deliberately returns Home and restarts that challenge next time. Use half-fold, not fully closed, during origami or the bridge challenge.
- The first walk-out happens only once on an unplayed journey near Home. Existing saved adventures resume exactly and do not replay it.
- Path choices intentionally begin the new adult act at its authored starting place. Ordinary folding, reopening, walking, and scene entrances never teleport.
- Balance uses the visible slider; automatic device tilt is not implemented. Sound defaults off and can be enabled under **Settings → Paper & guqin sounds**.
- On-device poem generation may be unavailable in the simulator; each quest has a complete curated bilingual fallback.
- Live App Store billing is not configured. Debug/simulator builds use Test Store, while release builds leave Act I and Home free until the live SDK key and store products are supplied. Network access is needed for first-time offering/purchase checks; there is no local fake-Pro switch.
- Avoid the hidden Path Editor during a normal demo: hold the mini-map for two seconds only when intentionally editing the road.
