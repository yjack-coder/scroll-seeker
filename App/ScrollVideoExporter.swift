@preconcurrency import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ScrollVideoExporter {
  private(set) var progress = 0.0
  private(set) var isExporting = false
  private(set) var videoURL: URL?
  private(set) var previewImage: UIImage?
  private(set) var errorMessage: String?

  @ObservationIgnored private var isCancelled = false
  @ObservationIgnored private var writer: AVAssetWriter?
  private let width = 960
  private let height = 640
  private let framesPerSecond: Int32 = 20
  private let frameCount = 120

  func export(_ entry: JournalEntry) async {
    guard !isExporting, videoURL == nil else { return }
    isCancelled = false
    errorMessage = nil
    progress = 0
    isExporting = true
    defer {
      writer = nil
      isExporting = false
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Liubai-\(UUID().uuidString).mp4")
    do {
      let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
      writer = assetWriter
      let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: width,
          AVVideoHeightKey: height,
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_000_000,
            AVVideoExpectedSourceFrameRateKey: framesPerSecond,
            AVVideoMaxKeyFrameIntervalKey: framesPerSecond,
          ],
        ])
      input.expectsMediaDataInRealTime = false
      let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
          kCVPixelBufferWidthKey as String: width,
          kCVPixelBufferHeightKey as String: height,
          kCVPixelBufferCGImageCompatibilityKey as String: true,
          kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ])
      guard assetWriter.canAdd(input) else { throw ScrollExportError.encoding }
      assetWriter.add(input)
      guard assetWriter.startWriting() else { throw ScrollExportError.encoding }
      assetWriter.startSession(atSourceTime: .zero)

      for frame in 0..<frameCount {
        try checkCancellation()
        let readyDeadline = Date.now.addingTimeInterval(15)
        while !input.isReadyForMoreMediaData {
          try checkCancellation()
          guard assetWriter.status == .writing, Date.now < readyDeadline else {
            throw ScrollExportError.encoding
          }
          try await Task.sleep(for: .milliseconds(10))
        }
        let time = Double(frame) / Double(framesPerSecond)
        let image = try renderFrame(entry: entry, time: time)
        let buffer = try pixelBuffer(image, pool: adaptor.pixelBufferPool)
        let presentationTime = CMTime(value: Int64(frame), timescale: framesPerSecond)
        guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
          throw ScrollExportError.encoding
        }
        if frame % 8 == 0 || frame == frameCount - 1 {
          previewImage = UIImage(cgImage: image)
        }
        progress = Double(frame + 1) / Double(frameCount) * 0.96
        // Give gestures, cancellation, and the progress view time between rendered frames.
        try await Task.sleep(for: .milliseconds(1))
      }
      input.markAsFinished()
      assetWriter.endSession(
        atSourceTime: CMTime(value: Int64(frameCount), timescale: framesPerSecond))
      await assetWriter.finishWriting()
      try checkCancellation()
      guard assetWriter.status == .completed else { throw ScrollExportError.encoding }
      videoURL = outputURL
      progress = 1
    } catch {
      writer?.cancelWriting()
      // Only this operation's uniquely named incomplete movie is removed.
      try? FileManager.default.removeItem(at: outputURL)
      if !(error is CancellationError), !isCancelled {
        errorMessage = error.localizedDescription
      }
    }
  }

  func cancel() {
    isCancelled = true
  }

  private func checkCancellation() throws {
    if isCancelled || Task.isCancelled { throw CancellationError() }
  }

  private func renderFrame(entry: JournalEntry, time: Double) throws -> CGImage {
    let unroll = ease((time - 0.2) / 1.5)
    let ink = ease((time - 0.65) / 3.0)
    let poem = max(0, min(1, (time - 3.4) / 1.45))
    let content = ScrollMovieFrame(
      entry: entry, unroll: unroll, ink: ink,
      poem: poem, showSeal: time >= 5.0
    )
    .frame(width: CGFloat(width), height: CGFloat(height))
    .environment(\.colorScheme, .light)
    .environment(\.dynamicTypeSize, .medium)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    renderer.isOpaque = true
    guard let image = renderer.cgImage else { throw ScrollExportError.rendering }
    return image
  }

  private func pixelBuffer(_ image: CGImage, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let result: CVReturn
    if let pool {
      result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
    } else {
      result = CVPixelBufferCreate(
        kCFAllocatorDefault, width, height,
        kCVPixelFormatType_32ARGB,
        [
          kCVPixelBufferCGImageCompatibilityKey: true,
          kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary,
        &buffer)
    }
    guard result == kCVReturnSuccess, let buffer else { throw ScrollExportError.rendering }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    else {
      throw ScrollExportError.rendering
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
  }

  private func ease(_ value: Double) -> Double {
    let progress = max(0, min(1, value))
    return progress * progress * (3 - 2 * progress)
  }
}

private struct ScrollMovieFrame: View {
  var entry: JournalEntry
  var unroll: Double
  var ink: Double
  var poem: Double
  var showSeal: Bool

  var body: some View {
    ZStack {
      LiubaiStyle.paper
      VStack(spacing: 20) {
        PaintedScroll(
          entry: entry, unroll: unroll, ink: ink, poem: poem,
          showSeal: showSeal, isPro: true, living: false
        )
        .frame(height: 514)
        HStack(alignment: .firstTextBaseline) {
          Text(entry.title).font(.system(size: 15, design: .serif))
          Spacer()
          Text("留白  Liubai").font(LiubaiStyle.brush(20))
        }
        .foregroundStyle(LiubaiStyle.muted)
        .padding(.horizontal, 25)
        .opacity(max(0, poem * 2 - 1))
      }
      .padding(.horizontal, 30)
      .padding(.vertical, 28)
    }
  }
}

private enum ScrollExportError: LocalizedError {
  case rendering, encoding
  var errorDescription: String? {
    switch self {
    case .rendering: "The painting could not be rendered into a video. Please try again."
    case .encoding:
      "The video could not be saved. Check that your device has free space and try again."
    }
  }
}
