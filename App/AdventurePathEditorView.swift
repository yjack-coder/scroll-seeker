import SwiftUI
import UIKit

struct AdventurePathEditorView: View {
  var game: AdventureGame
  var painting: ScrollArchive
  var onClose: () -> Void
  @State private var draft: [AdventurePathPoint]
  @State private var status: String?

  init(game: AdventureGame, painting: ScrollArchive, onClose: @escaping () -> Void) {
    self.game = game
    self.painting = painting
    self.onClose = onClose
    _draft = State(initialValue: game.walkPath.points)
  }

  var body: some View {
    NavigationStack {
      ScrollSearchCanvas(
        archive: painting, activeTarget: nil, foundTargets: [], museumMode: false,
        hintTarget: nil, hintTrigger: 0, onTap: { _, _ in }, onViewportChange: { _ in },
        chapterID: "path-editor", startX: game.heroX, chapterRange: 0...1,
        isActive: true, heroPosition: CGPoint(x: game.heroX, y: game.heroY),
        heroStage: game.selectedOutfit, maximumZoom: 6,
        pathPoints: draft.sorted { $0.x > $1.x }, isEditingPath: true,
        onPathPointMove: movePoint, onPathPointDelete: deletePoint, onPathPointAdd: addPoint
      )
      .navigationTitle("Walking path · \(draft.count) points")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark", action: onClose)
            .accessibilityHint("Discards changes made since the last save.")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", systemImage: "checkmark", action: save)
            .disabled(draft.count < 2)
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 9) {
          Text("Drag yellow points · Tap to add · Hold a point to delete · Pan and pinch to explore")
            .font(.system(.caption2, design: .serif)).multilineTextAlignment(.center)
          if let status {
            Text(status).font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.red)
              .multilineTextAlignment(.center).accessibilityIdentifier("path-editor-status")
          }
          HStack(spacing: 12) {
            Button("Copy JSON", systemImage: "document.on.document", action: copyJSON)
            Button("Reset draft", systemImage: "arrow.counterclockwise") {
              draft = game.walkPath.points
              status = "Draft restored to the current saved path."
            }
            Spacer(minLength: 0)
            Button("Done", action: onClose)
          }
          .font(.system(.caption, design: .serif)).buttonStyle(.bordered)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity).background(SeekerStyle.paper.opacity(0.96))
      }
      .onAppear { game.stopWorld() }
    }
    .tint(SeekerStyle.indigo)
  }

  private func movePoint(_ id: UUID, _ position: CGPoint) {
    guard position.x.isFinite, position.y.isFinite,
      let index = draft.firstIndex(where: { $0.id == id }) else { return }
    draft[index].x = min(1, max(0, position.x))
    draft[index].y = min(1, max(0, position.y))
    status = nil
  }

  private func addPoint(_ position: CGPoint) {
    guard position.x.isFinite, position.y.isFinite else { return }
    draft.append(AdventurePathPoint(x: min(1, max(0, position.x)), y: min(1, max(0, position.y))))
    status = nil
  }

  private func deletePoint(_ id: UUID) {
    guard draft.count > 2 else {
      status = "Keep at least two points on the path."
      return
    }
    draft.removeAll { $0.id == id }
    status = nil
  }

  private func save() {
    let ordered = draft.sorted { $0.x > $1.x }
    if game.saveWalkPath(points: ordered) {
      draft = game.walkPath.points
      status = "Saved on this device; overrides bundled path"
    } else {
      status = game.walkPath.lastError ?? "The path could not be saved. Check its points and try again."
    }
  }

  private func copyJSON() {
    let json = AdventureWalkPath.jsonString(for: draft.sorted { $0.x > $1.x })
    guard !json.isEmpty else { status = "The draft could not be copied."; return }
    UIPasteboard.general.string = json
    status = "Path JSON copied."
  }
}
