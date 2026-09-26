import SwiftUI

struct AdventureExamChallenge: View {
    var posture: AdventurePostureStore
    var onSuccess: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: ExamPhase = .questions
    @State private var questionIndex = 0
    @State private var selectedID: String?
    @State private var firstChoiceScore = 0
    @State private var sealCount = 0
    @State private var submitted = false
    private let questions = AdventureQuestion.forMission("a5")

    var body: some View {
        VStack(spacing: 22) {
            switch phase {
            case .questions: questionPaper
            case .readyToSeal:
                paper(sealed: false)
                Text("糊名 · Seal your name").font(SeekerStyle.brush(27))
                Text("摺起考卷，讓名字藏在紅印之下。\nFold the paper so your name rests beneath the red seal.")
                    .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                Button(posture.current == .folded ? "先展卷 · Open the paper first" : "合上交卷 · Fold to submit") {
                    posture.set(posture.current == .folded ? .open : .folded)
                }.buttonStyle(SeekerActionStyle())
                foldHint("Folded posture seals the paper. The button performs the same action.")
            case .sealed:
                paper(sealed: true)
                Text("閱卷中…").font(SeekerStyle.brush(35))
                Text("Grading…").font(.system(.title3, design: .serif))
                Text("名字已封，答案自有分量。\nYour name is hidden. Let the answers speak.")
                    .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                Button("展卷放榜 · Unfold the results") { posture.set(.open) }
                    .buttonStyle(SeekerActionStyle())
                foldHint("Change to Open posture to unroll the results.")
            case .results:
                VStack(spacing: 18) {
                    Text(firstChoiceScore == 3 ? "金榜題名" : "再磨一硯墨")
                        .font(SeekerStyle.brush(35)).foregroundStyle(SeekerStyle.red)
                    Text(firstChoiceScore == 3 ? "狀元 · Top Scholar" : firstChoiceScore == 2 ? "漸入佳境 · A promising scholar" : "仍須磨鍊 · More study awaits")
                        .font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
                    Text("\(firstChoiceScore) / 3 首答正確 · correct on the first choice")
                        .font(.system(.body, design: .serif))
                    if firstChoiceScore == 3 {
                        Text("三問皆明，筆下有光。\nThree thoughtful answers. Your name rises to the top.")
                            .multilineTextAlignment(.center).font(.system(.body, design: .serif))
                        Button("領榜 · Accept the result") {
                            guard !submitted else { return }
                            submitted = true
                            onSuccess()
                        }.buttonStyle(SeekerActionStyle()).disabled(submitted)
                    } else {
                        Text("這一卷還未取得狀元。讀過評語，再試一次；不扣銅錢。\nThis paper has not earned Top Scholar. Study the notes and take a fresh attempt—no coins are lost.")
                            .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                        Button("再試一卷 · Retake for top rank", action: retake)
                            .buttonStyle(SeekerActionStyle())
                    }
                }
                .padding(22).frame(maxWidth: .infinity)
                .background(SeekerStyle.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }
        }
        .foregroundStyle(SeekerStyle.ink)
        .onChange(of: posture.current) { _, pose in
            if phase == .readyToSeal && pose == .folded {
                phase = .sealed
                sealCount += 1
            } else if phase == .sealed && pose == .open {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.1)) { phase = .results }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: sealCount)
    }

    private var questionPaper: some View {
        let question = questions[questionIndex]
        return VStack(spacing: 18) {
            Text("第 \(questionIndex + 1) 問 · QUESTION \(questionIndex + 1) OF 3")
                .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.gold)
            Text(question.chinese).font(SeekerStyle.brush(25)).multilineTextAlignment(.center)
            Text(question.english).font(.system(.body, design: .serif)).multilineTextAlignment(.center)
            ForEach(question.answers) { answer in
                Button {
                    guard selectedID == nil else { return }
                    selectedID = answer.id
                    if answer.correct { firstChoiceScore += 1 }
                } label: {
                    VStack(spacing: 6) {
                        Text(answer.chinese).font(SeekerStyle.brush(21))
                        Text(answer.english).font(.system(.subheadline, design: .serif))
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(SeekerActionStyle(secondary: selectedID != answer.id))
                .disabled(selectedID != nil)
            }
            if let selectedID {
                let correct = question.answers.first { $0.correct }
                Text(question.answers.first(where: { $0.id == selectedID })?.correct == true
                     ? "這一答很穩。A thoughtful answer."
                     : "參考答案：\(correct?.chinese ?? "")\nConsider: \(correct?.english ?? "")")
                    .font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.gold)
                    .multilineTextAlignment(.center)
                Button(questionIndex == 2 ? "整理考卷 · Prepare the paper" : "下一問 · Next question") {
                    if questionIndex == 2 { phase = .readyToSeal }
                    else { questionIndex += 1; self.selectedID = nil }
                }.buttonStyle(SeekerActionStyle())
            }
            Text("每題只記第一次作答。放榜後可以重考。\nOnly the first answer counts. A fresh attempt is available after the results.")
                .font(.system(.caption, design: .serif)).multilineTextAlignment(.center)
                .foregroundStyle(SeekerStyle.ink.opacity(0.7))
        }
    }

    private func paper(sealed: Bool) -> some View {
        VStack(spacing: 16) {
            Text(sealed ? "糊名卷" : "小安 · Xiao An").font(SeekerStyle.brush(25))
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(SeekerStyle.gold.opacity(0.26)).frame(height: 1)
            }
            if sealed {
                Text("封").font(SeekerStyle.brush(36)).foregroundStyle(SeekerStyle.paper)
                    .frame(width: 51, height: 56).background(SeekerStyle.red, in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(26).frame(maxWidth: 300)
        .background(SeekerStyle.paper, in: RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(SeekerStyle.gold, lineWidth: 1) }
        .shadow(color: SeekerStyle.ink.opacity(0.12), radius: 12, y: 4)
        .accessibilityLabel(sealed ? "Anonymous examination paper with a red seal" : "Examination paper showing Xiao An's name")
    }

    private func foldHint(_ text: String) -> some View {
        Text("摺法提示 · " + text).font(.system(.caption, design: .serif))
            .padding(12).frame(maxWidth: .infinity)
            .background(SeekerStyle.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
    }

    private func retake() {
        questionIndex = 0
        selectedID = nil
        firstChoiceScore = 0
        phase = .questions
        posture.set(.open)
    }

    private enum ExamPhase { case questions, readyToSeal, sealed, results }
}
