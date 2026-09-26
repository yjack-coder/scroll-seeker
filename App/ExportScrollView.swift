import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct ExportScrollView: View {
  var entry: JournalEntry
  @State private var exporter = ScrollVideoExporter()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 26) {
          ExportScrollHeading(title: entry.title)
          ExportScrollPreview(entry: entry, image: exporter.previewImage)
          ExportScrollActions(entry: entry, exporter: exporter)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
      }
      .background(LiubaiStyle.paper)
      .navigationTitle("Share a moment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            exporter.cancel()
            dismiss()
          }
        }
      }
      .tint(LiubaiStyle.red)
      .task { await exporter.export(entry) }
      .onDisappear { exporter.cancel() }
    }
    .preferredColorScheme(.light)
  }
}

private struct ExportScrollHeading: View {
  var title: String
  var body: some View {
    VStack(spacing: 11) {
      Text(title)
        .font(.system(.title2, design: .serif))
        .foregroundStyle(LiubaiStyle.ink)
      Text("A small unfolding. A little room to breathe.")
        .font(.system(.subheadline, design: .serif))
        .foregroundStyle(LiubaiStyle.muted)
    }
    .multilineTextAlignment(.center)
  }
}

private struct ExportScrollPreview: View {
  var entry: JournalEntry
  var image: UIImage?
  var body: some View {
    ZStack {
      LiubaiStyle.paper
      if let image {
        Image(uiImage: image).resizable().scaledToFit()
      } else {
        PaintedScroll(entry: entry, isPro: true, living: false).padding(15)
      }
    }
    .aspectRatio(1.5, contentMode: .fit)
    .overlay { Rectangle().strokeBorder(LiubaiStyle.rule.opacity(0.45), lineWidth: 0.5) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Video preview: \(entry.title)")
  }
}

private struct ExportScrollActions: View {
  var entry: JournalEntry
  var exporter: ScrollVideoExporter

  var body: some View {
    VStack(spacing: 18) {
      if let url = exporter.videoURL {
        Text("Your six-second scroll is ready.")
          .font(.system(.subheadline, design: .serif))
          .foregroundStyle(LiubaiStyle.muted)
        ShareLink(
          item: SharedScrollMovie(url: url),
          preview: SharePreview(entry.title)
        ) {
          Label("Share video", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(InkButtonStyle())
      } else if exporter.isExporting {
        ProgressView(value: exporter.progress) {
          Text(exporter.progress < 0.96 ? "Unrolling your painting…" : "Finishing the video…")
            .font(.system(.subheadline, design: .serif))
        } currentValueLabel: {
          Text(exporter.progress, format: .percent.precision(.fractionLength(0)))
            .monospacedDigit()
        }
        .tint(LiubaiStyle.red)
        .accessibilityLabel("Creating unroll video")
        Text("Made on your device. Your original words stay in your journal.")
          .font(.footnote)
          .foregroundStyle(LiubaiStyle.muted)
          .multilineTextAlignment(.center)
      } else if let error = exporter.errorMessage {
        Text(error)
          .font(.system(.subheadline, design: .serif))
          .foregroundStyle(LiubaiStyle.ink)
          .multilineTextAlignment(.center)
        Button("Try again", systemImage: "arrow.clockwise") {
          Task { await exporter.export(entry) }
        }
        .buttonStyle(InkButtonStyle())
      }
    }
    .frame(maxWidth: .infinity)
  }
}

private struct SharedScrollMovie: Transferable {
  var url: URL
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .mpeg4Movie) { movie in
      SentTransferredFile(movie.url)
    }
  }
}
