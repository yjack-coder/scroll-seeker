import SwiftUI

struct AdventureCoupletChallenge: View {
    var rounds: [AdventureQuestion]
    var onSuccess: () -> Void
    @State private var round = 0
    @State private var response: String?

    var body: some View {
        VStack(spacing: 20) {
            if rounds.indices.contains(round) {
                let question = rounds[round]
                Text("對句 \(round + 1) / \(rounds.count) · MATCH THE VERSE")
                    .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.gold)
                Text("拖入相稱的下聯，也可以點選。")
                    .font(SeekerStyle.brush(22))
                Text("Drag the answering line into the empty scroll, or tap a line to choose it.")
                    .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    Text(question.chinese).font(SeekerStyle.brush(32)).tracking(3)
                    Text(question.english).font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
                    Rectangle().fill(SeekerStyle.gold.opacity(0.4)).frame(height: 1)
                    Text("下聯 · YOUR ANSWERING LINE")
                        .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.gold)
                        .frame(maxWidth: .infinity).frame(minHeight: 70)
                        .background(SeekerStyle.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
                        .dropDestination(for: String.self) { items, _ in
                            guard let id = items.first, let answer = question.answers.first(where: { $0.id == id }) else { return false }
                            choose(answer, question: question)
                            return true
                        }
                }
                .padding(20).background(SeekerStyle.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                ForEach(question.answers) { answer in
                    Button { choose(answer, question: question) } label: {
                        VStack(spacing: 6) {
                            Text(answer.chinese).font(SeekerStyle.brush(23))
                            Text(answer.english).font(.system(.subheadline, design: .serif))
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SeekerActionStyle(secondary: true))
                    .draggable(answer.id)
                }
                if let response {
                    Text(response).font(.system(.subheadline, design: .serif))
                        .foregroundStyle(SeekerStyle.red).multilineTextAlignment(.center)
                }
            }
        }
        .foregroundStyle(SeekerStyle.ink)
    }

    private func choose(_ answer: AdventureAnswer, question: AdventureQuestion) {
        if answer.correct {
            response = nil
            if round == rounds.count - 1 { onSuccess() } else { round += 1 }
        } else { response = question.retry }
    }
}
