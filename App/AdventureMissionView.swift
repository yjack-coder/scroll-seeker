import SwiftUI

/// Arrival starts a conversation. Only finishing the playable challenge sends a
/// completion event; the adventure model owns all rewards and story progress.
struct AdventureMissionView: View {
    var mission: AdventureMission
    var posture: AdventurePostureStore
    var onComplete: () -> Void
    var onLeave: () -> Void
    @State private var phase: MissionPhase = .conversation
    @State private var didComplete = false

    private var scene: AdventureMissionScene { AdventureMissionScene.forMission(mission.id) }
    private var laptopChallenge: Bool {
        phase == .challenge && posture.current == .laptop && (mission.id == "m1" || mission.id == "m3")
    }

    var body: some View {
        GeometryReader { geometry in
            if mission.id == "m_paperboat", phase == .challenge {
                AdventureOrigamiChallenge(posture: posture, onSuccess: succeeded)
                    .overlay(alignment: .topTrailing) {
                        Button("Later / 稍後", action: onLeave)
                            .font(.system(.caption, design: .serif)).padding(14)
                            .background(.ultraThinMaterial, in: Capsule()).padding(12)
                    }
            } else {
                page(availableHeight: geometry.size.height)
            }
        }
        .background { SilkBackground().ignoresSafeArea() }
        .tint(SeekerStyle.indigo)
        .interactiveDismissDisabled(phase == .succeeded)
        .sensoryFeedback(.success, trigger: phase == .succeeded)
    }

    private func page(availableHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: laptopChallenge ? 0 : 24) {
                VStack(spacing: 24) {
                    HStack {
                        Text(phase == .conversation ? "相逢 · A MEETING" : "畫中一事 · YOUR PART IN THE STORY")
                            .font(.system(.caption2, design: .serif)).tracking(1.6)
                            .foregroundStyle(SeekerStyle.gold)
                        Spacer()
                        Button("Later / 稍後", action: onLeave)
                            .font(.system(.subheadline, design: .serif))
                            .frame(minHeight: 44)
                    }
                    VStack(spacing: 6) {
                        Text(mission.chineseName).font(SeekerStyle.brush(34))
                        Text(mission.englishName).font(.system(.title3, design: .serif))
                    }
                    .foregroundStyle(SeekerStyle.indigo)
                    if phase == .challenge && (mission.id == "m1" || mission.id == "m3") {
                        Button("書桌姿勢 · Use Laptop control desk") { posture.set(.laptop) }
                            .font(.system(.subheadline, design: .serif)).frame(minHeight: 44)
                    }
                    Rectangle().fill(SeekerStyle.gold.opacity(0.45)).frame(width: 48, height: 1)
                }
                .frame(height: laptopChallenge ? 0 : nil)
                .opacity(laptopChallenge ? 0 : 1)
                .accessibilityHidden(laptopChallenge)
                .allowsHitTesting(!laptopChallenge)

                if phase == .conversation {
                    dialogue
                } else if phase == .challenge {
                    challenge
                        .frame(height: laptopChallenge ? availableHeight : nil)
                } else {
                    VStack(spacing: 18) {
                        Text(mission.sealName).font(SeekerStyle.brush(mission.sealName.count > 1 ? 30 : 55))
                            .foregroundStyle(SeekerStyle.paper)
                            .frame(width: 78, height: 86)
                            .background(SeekerStyle.red, in: RoundedRectangle(cornerRadius: 5))
                        Text(scene.successChinese).font(SeekerStyle.brush(24))
                        Text(scene.successEnglish).font(.system(.body, design: .serif))
                            .multilineTextAlignment(.center)
                        Button("Continue the story / 故事繼續", action: complete)
                            .buttonStyle(SeekerActionStyle())
                            .disabled(didComplete)
                    }
                    .foregroundStyle(SeekerStyle.indigo)
                    .padding(.vertical, 24)
                }
            }
            .padding(laptopChallenge ? 0 : 24).padding(.top, laptopChallenge ? 0 : 12)
            .frame(maxWidth: laptopChallenge || (mission.id == "m4" && phase == .challenge) ? .infinity : 600)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) {
            if laptopChallenge {
                HStack(spacing: 15) {
                    Button("展開 · Open") { posture.set(.open) }
                    Button("稍後 · Later", action: onLeave)
                }
                .font(.system(.subheadline, design: .serif))
                .padding(.horizontal, 18).frame(height: 48)
                .background(SeekerStyle.paper.opacity(0.96), in: Capsule())
                .padding(8)
            }
        }
    }

    private var dialogue: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(scene.dialogue) { line in
                VStack(alignment: .leading, spacing: 8) {
                    Text(line.speaker).font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundStyle(SeekerStyle.red)
                    Text(line.chinese).font(SeekerStyle.brush(23)).lineSpacing(5)
                    Text(line.english).font(.system(.body, design: .serif)).lineSpacing(4)
                        .foregroundStyle(SeekerStyle.ink.opacity(0.8))
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(SeekerStyle.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            Button(mission.id == "m6" ? "Give Mother the bottle / 把醬油交給娘" : "Lend a hand / 我來幫忙") {
                phase = mission.id == "m6" ? .succeeded : .challenge
            }
            .buttonStyle(SeekerActionStyle())
            Text("Your choices and actions move the story forward. You can always try again.")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(SeekerStyle.ink.opacity(0.68))
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
        .foregroundStyle(SeekerStyle.ink)
    }

    @ViewBuilder private var challenge: some View {
        switch mission.id {
        case "m1":
            AdventureDonkeyChallenge(posture: posture, onSuccess: succeeded)
        case "m2", "a2", "a3":
            AdventureChoiceChallenge(questions: AdventureQuestion.forMission(mission.id), onSuccess: succeeded)
        case "m_paperboat":
            AdventureOrigamiChallenge(posture: posture, onSuccess: succeeded)
        case "m3":
            AdventureTimingChallenge(kind: .rowing, onSuccess: succeeded, posture: posture)
        case "m4":
            AdventureBridgeChallenge(posture: posture, onSuccess: succeeded)
        case "m5":
            AdventureBottleChallenge(onSuccess: succeeded)
        case "a1", "a4":
            AdventureCoupletChallenge(rounds: AdventureQuestion.forMission(mission.id), onSuccess: succeeded)
        case "a5":
            AdventureExamChallenge(posture: posture, onSuccess: succeeded)
        case "b1", "b2", "b3", "b5":
            AdventureStealthChallenge(missionID: mission.id, posture: posture, onSuccess: succeeded)
        case "b4":
            AdventureTimingChallenge(kind: .purse, onSuccess: succeeded)
        case "m6":
            Button("Deliver the bottle / 交給娘") { succeeded() }.buttonStyle(SeekerActionStyle())
        default:
            Text(mission.task).font(.system(.body, design: .serif))
        }
    }

    private func succeeded() { phase = .succeeded }
    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }

    private enum MissionPhase { case conversation, challenge, succeeded }
}

struct AdventureMissionScene {
    var dialogue: [AdventureDialogue]
    var successChinese: String
    var successEnglish: String

    static func forMission(_ id: String) -> AdventureMissionScene {
        switch id {
        case "m1": return scene([
            .init("炭翁 · Charcoal seller", "三頭驢兒走散了。小安，幫我把牠們牽回隊伍，好嗎？", "Three donkeys have wandered apart. Xiao An, will you bring them back into line?"),
            .init("小安 · Xiao An", "別急，我一頭一頭牽回來。", "Don’t worry. I’ll lead them back, one at a time.")
        ], "驢隊又上路了。", "The caravan is together again. The road feels a little kinder.")
        case "m2": return scene([
            .init("行旅 · Traveler", "柳蔭下的路有好幾條。孩子，你要往哪裡去？", "There are several paths beneath these willows. Where are you going, child?"),
            .init("小安 · Xiao An", "娘叫我去虹橋打醬油。我該怎麼問路呢？", "Mother sent me to Rainbow Bridge for soy sauce. How should I ask the way?")
        ], "沿著柳樹，便能看見汴河。", "Follow the willows; the river will meet you at the end of the path.")
        case "m_paperboat": return scene([
            .init("橋邊孩子 · Child by the stream", "我的紙船沉下去了……它還沒走過小橋呢。", "My paper boat sank… it never even reached the little bridge."),
            .init("小安 · Xiao An", "別哭，我們再摺一隻。這一道摺痕，就是新的河岸。", "Don’t cry. Let’s fold another. This little crease can be a new beginning.")
        ], "紙船又出發了。", "Three folds, a small kindness. The child watches a new boat drift beneath the bridge.")
        case "m3": return scene([
            .init("船夫 · Boatman", "水流緊，大家得一起使勁。聽我的拍子：預備——拉！", "The current is strong. We must pull together. Follow my beat: ready—pull!"),
            .init("小安 · Xiao An", "我握穩繩子了。你喊，我就拉。", "I have the rope. Call the beat and I’ll pull with you.")
        ], "眾人同心，船便前行。", "Three steady pulls carry the boat clear of the bank.")
        case "m4": return scene([
            .init("橋上人 · A voice on the bridge", "船來了！高桅快碰上橋了！", "The boat is coming! Its tall mast is about to strike the bridge!"),
            .init("小安 · Xiao An", "等船靠近，我把畫卷半摺，就能放下桅杆。", "When the boat draws close, I can half-fold the scroll to lower its mast.")
        ], "一摺解危，輕舟過橋。", "A well-timed fold lowers the mast. The boat passes safely beneath the bridge.")
        case "m5": return scene([
            .init("醬油販 · Sauce seller", "醬油香，瓶子滿。先商量個公道價，再穩穩拿好。", "Good sauce and a full bottle. Let’s agree on a fair price, then keep your hands steady."),
            .init("小安 · Xiao An", "這是娘交給我的差事，一滴也不能灑。", "Mother trusted me with this errand. I must not spill a drop.")
        ], "醬油裝好了，回家吧。", "The bottle is filled and steady. Now the road leads home.")
        case "m6": return scene([
            .init("娘 · Mother", "安兒回來了。路上可順利？", "You’re home, An. Was the journey kind to you?"),
            .init("小安 · Xiao An", "我幫了幾個人，也帶回了娘要的醬油。", "I helped a few people—and brought the soy sauce you asked for."),
            .init("娘 · Mother", "去時是小小差事，回來已長大一點。", "Such a small errand, and you return a little wiser.")
        ], "一瓶醬油，一段人生。", "One bottle, one journey. Beyond the bridge, another life awaits.")
        case "a1": return scene([
            .init("書生 · Fellow scholar", "想借這卷書？先替窗前的上聯，配個下聯。", "Would you borrow this book? First, find the line that answers the verse by the window."),
            .init("小安 · Xiao An", "字要相稱，意思也要相照。", "The words should balance, and their meanings should answer one another.")
        ], "以詩會友，以書同行。", "A well-matched verse earns a borrowed book and a new friend.")
        case "a2": return scene([
            .init("守門人 · Gatekeeper", "入京何事？請說明來意。", "What brings you to the capital? State your purpose."),
            .init("小安 · Xiao An", "我帶著書卷與文書，來赴一場考試。", "I carry my books and papers. I have come for the examination.")
        ], "城門開了，前路也開了。", "The gatekeeper accepts your honest answer. The capital opens before you.")
        case "a3": return scene([
            .init("商人 · Ink merchant", "墨有許多種。你要的，是耀眼的盒子，還是筆下清楚的一行字？", "There are many inks. Are you seeking a splendid box, or a clear line beneath your brush?"),
            .init("小安 · Xiao An", "我想選一塊能伴我把字寫好的墨。", "I want ink that will help me write with care.")
        ], "好墨在手，心定筆穩。", "You choose the ink for its mark, not its wrapping.")
        case "a4": return scene([
            .init("詩會主人 · Poetry host", "酒未斟，詩先來。請為這兩句，尋一個相稱的回答。", "Before the wine, a verse. Find a fitting answer to each of these lines."),
            .init("小安 · Xiao An", "讓山水成對，也讓心意相逢。", "Let mountain answer water, and one thought meet another.")
        ], "滿座無聲，而後喝彩。", "A quiet room, then applause. Your verses find their answering lines.")
        case "a5": return scene([
            .init("考官 · Examiner", "最後三問。讀清楚，想明白，再落筆。", "Three final questions. Read carefully, think clearly, then choose your answer."),
            .init("小安 · Xiao An", "答完糊好名字，摺起交卷；再展卷時，就是放榜了。", "When I finish, I’ll fold the paper to seal my name. Unfolding will reveal the results.")
        ], "金榜題名。", "Your answers are sound. Xiao An’s name stands at the top of the list.")
        case "b1": return scene([
            .init("碼頭人 · Dockside neighbor", "糧食鎖在船上，街坊卻空著肚子。看守回頭時，先藏好。", "Grain is locked aboard while the neighbors go hungry. Keep hidden whenever the watchman turns."),
            .init("小安 · Xiao An", "我只取夠分給街坊的糧食。", "I’ll take only enough to share with the neighbors.")
        ], "糧食有了去處。", "You reach the grain without an alarm. Tonight it will fill empty bowls.")
        case "b2": return scene([
            .init("守門人 · Gate guard", "燈照到哪裡，就查到哪裡。", "Search wherever the lantern falls."),
            .init("小安 · Xiao An", "摺起作屏，等燈光走遠，再入城。", "I’ll fold a screen around my shadow, then enter when the light has passed.")
        ], "燈影走遠，城門在前。", "The lantern passes. You slip through the gate unseen.")
        case "b3": return scene([
            .init("車夫 · Carter", "貨堆裡能藏人。守衛望過來，就別動。", "There’s room among the sacks. Stay still whenever the guard looks this way."),
            .init("小安 · Xiao An", "一陣風的工夫，就能躲進去。", "A moment’s opening is all I need.")
        ], "車輪向前，身影藏好。", "Hidden among the goods, you pass quietly into the city.")
        case "b4": return scene([
            .init("小安 · Xiao An", "轎子晃動時，錢袋會露出來。只等那一瞬。", "When the sedan sways, the purse comes within reach. Wait for that brief opening."),
            .init("街坊 · Neighbor", "那些銀錢，本該讓窮人有飯吃。", "That silver should have filled the neighbors’ bowls.")
        ], "取之不義，用之有情。", "The purse is in hand. Its silver will find a kinder purpose.")
        case "b5": return scene([
            .init("小安 · Xiao An", "最後一道城門。燈影移開時走，守衛回頭時藏。", "One last gate. Move when the lantern turns away; hide when the guard looks back."),
            .init("街坊 · Neighbor", "我們在城外等你。", "We’ll be waiting outside the city.")
        ], "夜色藏名，燈火照人。", "You reach the neighbors safely. No one goes hungry tonight.")
        default: return scene([], "路還很長。", "The story continues.")
        }
    }

    private static func scene(_ lines: [AdventureDialogue], _ chinese: String, _ english: String) -> Self {
        Self(dialogue: lines, successChinese: chinese, successEnglish: english)
    }
}

struct AdventureDialogue: Identifiable {
    var speaker: String
    var chinese: String
    var english: String
    var id: String { chinese }
    init(_ speaker: String, _ chinese: String, _ english: String) {
        self.speaker = speaker; self.chinese = chinese; self.english = english
    }
}
