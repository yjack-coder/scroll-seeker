import SwiftUI

struct AdventureChoiceChallenge: View {
    var questions: [AdventureQuestion]
    var onSuccess: () -> Void
    @State private var round = 0
    @State private var response: String?

    var body: some View {
        VStack(spacing: 20) {
            if questions.indices.contains(round) {
                let question = questions[round]
                Text("\(round + 1) / \(questions.count)")
                    .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.gold)
                Text(question.chinese).font(SeekerStyle.brush(25)).multilineTextAlignment(.center)
                Text(question.english).font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                ForEach(question.answers) { answer in
                    Button {
                        if answer.correct {
                            response = nil
                            if round == questions.count - 1 { onSuccess() } else { round += 1 }
                        } else { response = question.retry }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(answer.chinese).font(SeekerStyle.brush(20))
                            Text(answer.english).font(.system(.subheadline, design: .serif))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(SeekerActionStyle(secondary: true))
                }
                if let response {
                    Text(response).font(.system(.subheadline, design: .serif))
                        .foregroundStyle(SeekerStyle.red).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .foregroundStyle(SeekerStyle.ink)
    }
}

struct AdventureQuestion {
    var chinese: String
    var english: String
    var answers: [AdventureAnswer]
    var retry: String = "再想一想。Take another look; there is no penalty for trying again."

    static func forMission(_ id: String) -> [Self] {
        switch id {
        case "m2": return [.init(chinese: "該怎麼開口？", english: "How will you ask the travelers?", answers: [
            .init("rush", "快讓開，我趕時間！", "Move aside. I’m in a hurry!"),
            .init("polite", "勞駕，請問往汴河怎麼走？", "Excuse me, which path leads to the Bian River?", true),
            .init("guess", "不問了，隨便走吧。", "No need to ask. I’ll choose any path.")
        ], retry: "行旅願意幫忙，只等一聲有禮的問候。The traveler is happy to help; begin with a courteous greeting.")]
        case "m5": return [.init(chinese: "怎樣談個公道價？", english: "How will you bargain for the bottle?", answers: [
            .init("threat", "不便宜些，我就把攤子弄亂。", "Lower the price or I’ll upset your stall."),
            .init("fair", "請給我裝滿，我們談個公道價，好嗎？", "May we agree on a fair price for a full bottle?", true),
            .init("leave", "把空瓶帶回去就好了。", "I’ll simply take the empty bottle home.")
        ], retry: "生意也要互相體諒。A fair bargain should work for both of you.")]
        case "a2": return [.init(chinese: "守門人問：入京何事？", english: "The gatekeeper asks why you are entering.", answers: [
            .init("papers", "我來應試，這是我的文書。", "I have come for the examination. Here are my papers.", true),
            .init("pretend", "我是大官，不許多問。", "I am an important official. Ask no questions."),
            .init("bribe", "給你錢，就別問了。", "Take these coins and stop asking.")
        ], retry: "不必裝腔，只須誠實。There is no need for a disguise; answer honestly.")]
        case "a3": return [.init(chinese: "哪一塊墨適合你的書卷？", english: "Which ink will you choose for your writing?", answers: [
            .init("box", "盒子最華麗的那塊。", "The one in the most splendid box."),
            .init("mark", "試寫時，細筆也清楚的那塊。", "The one whose test stroke stays clear, even in a fine line.", true),
            .init("cost", "只選最貴的，不用試。", "The most expensive one; no need to try it.")
        ], retry: "看筆下，不看包裝。Judge the mark beneath the brush, not its wrapping.")]
        case "a1": return [
            couplet("春風入柳巷", "Spring wind enters the willow lane", "細雨潤書窗", "Gentle rain softens the study window", "十里一條大路", "A long road for ten miles", "我欲買一瓶醬油", "I would like a bottle of soy sauce"),
            couplet("山靜藏雲影", "A quiet mountain shelters cloud shadows", "水清映月光", "Clear water mirrors moonlight", "昨日馬車來過", "A cart passed yesterday", "街上十分熱鬧", "The street is very busy")
        ]
        case "a4": return [
            couplet("一橋連兩岸", "One bridge joins two banks", "千帆過半城", "A thousand sails pass half the city", "明天還要出門", "Tomorrow I must go out", "有人提著一袋米", "Someone carries a sack of rice"),
            couplet("書窗留夜月", "The study window keeps the night moon", "酒巷起春風", "The tavern lane welcomes spring wind", "這裡有許多客人", "There are many guests here", "三十枚銅錢", "Thirty copper coins")
        ]
        case "a5": return [
            .init(chinese: "「春風吹柳綠」共有幾個字？", english: "How many characters are in 春風吹柳綠?", answers: [.init("four", "四字", "Four"), .init("five", "五字", "Five", true), .init("six", "六字", "Six")]),
            .init(chinese: "「山靜藏雲影」宜以哪一句相對？", english: "Which line balances ‘A quiet mountain shelters cloud shadows’?", answers: [.init("water", "水清映月光", "Clear water mirrors moonlight", true), .init("noise", "今天街上人很多", "There are many people in the street today"), .init("coin", "買兩枚銅錢", "Buy two copper coins")]),
            .init(chinese: "好友託你送書，途中遇雨，應當如何？", english: "You promised to deliver a friend’s book, but rain begins. What will you do?", answers: [.init("discard", "丟下書，自己先走。", "Leave the book and hurry away."), .init("care", "護好書卷，守住承諾。", "Protect the book and keep the promise.", true), .init("sell", "把書賣掉，買把傘。", "Sell the book to buy an umbrella.")])
        ]
        default: return []
        }
    }

    private static func couplet(_ first: String, _ firstEnglish: String, _ correct: String, _ correctEnglish: String, _ wrongA: String, _ wrongAEnglish: String, _ wrongB: String, _ wrongBEnglish: String) -> Self {
        Self(chinese: first, english: firstEnglish, answers: [
            .init("unmatched-a", wrongA, wrongAEnglish),
            .init("answer", correct, correctEnglish, true),
            .init("unmatched-b", wrongB, wrongBEnglish)
        ], retry: "再看字數與意象，讓兩句互相照應。Match the length and the images so the two lines answer one another.")
    }
}

struct AdventureAnswer: Identifiable {
    var id: String
    var chinese: String
    var english: String
    var correct: Bool
    init(_ id: String, _ chinese: String, _ english: String, _ correct: Bool = false) {
        self.id = id; self.chinese = chinese; self.english = english; self.correct = correct
    }
}
