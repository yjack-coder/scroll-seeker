import AVFAudio
import Foundation

/// Optional, entirely synthesized sounds; no microphone or downloaded audio is used.
@MainActor
final class ScrollSound {
  static let shared = ScrollSound()

  private let engine = AVAudioEngine()
  private var players: [ScrollSoundCue: AVAudioPlayerNode] = [:]
  private var buffers: [ScrollSoundCue: AVAudioPCMBuffer] = [:]
  private var idleTask: Task<Void, Never>?
  private var quietAfter = Date.distantPast
  private var isPrepared = false
  private let sampleRate = 44_100.0

  private init() {}

  func unroll() { play(.unroll) }
  func found() { play(.found) }
  func complete() { play(.complete) }
  func paperFold() { play(.paperFold) }

  private func play(_ cue: ScrollSoundCue) {
    guard UserDefaults.standard.bool(forKey: "seeker.soundEnabled") else {
      stop()
      return
    }

    do {
      guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
      else { return }

      if !isPrepared {
        for sound in ScrollSoundCue.allCases {
          let player = AVAudioPlayerNode()
          engine.attach(player)
          engine.connect(player, to: engine.mainMixerNode, format: format)
          players[sound] = player
        }
        engine.mainMixerNode.outputVolume = 0.40
        engine.prepare()
        isPrepared = true
      }

      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
      try session.setActive(true)
      if !engine.isRunning { try engine.start() }

      if buffers[cue] == nil { buffers[cue] = makeBuffer(for: cue, format: format) }
      guard let player = players[cue], let buffer = buffers[cue] else {
        stop()
        return
      }
      player.scheduleBuffer(buffer, at: nil, options: .interrupts)
      if !player.isPlaying { player.play() }

      // Release the engine and audio session once all of the short tails have faded.
      quietAfter = max(quietAfter, Date().addingTimeInterval(cue.duration + 0.20))
      idleTask?.cancel()
      let remaining = max(0, quietAfter.timeIntervalSinceNow)
      idleTask = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
        self?.stop()
      }
    } catch {
      // Sound is decorative. Audio-session interruptions never interrupt the game.
      stop()
    }
  }

  private func stop() {
    idleTask?.cancel()
    idleTask = nil
    for player in players.values { player.stop() }
    engine.stop()
    quietAfter = .distantPast
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func makeBuffer(for cue: ScrollSoundCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
    let frameCount = AVAudioFrameCount(sampleRate * cue.duration)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
      let samples = buffer.floatChannelData?[0]
    else { return nil }
    buffer.frameLength = frameCount

    var noiseState: UInt64 = 0x51554D494E47
    var lowNoise = 0.0
    var softerNoise = 0.0
    for frame in 0..<Int(frameCount) {
      let time = Double(frame) / sampleRate
      var signal = 0.0
      switch cue {
      case .unroll, .paperFold:
        // Two smoothed noise bands suggest the soft drag of paper, without hiss.
        noiseState = noiseState &* 6_364_136_223_846_793_005 &+ 1
        let whiteNoise = Double(noiseState >> 40) / 8_388_608.0 - 1
        lowNoise += 0.055 * (whiteNoise - lowNoise)
        softerNoise += 0.012 * (whiteNoise - softerNoise)
        let envelope = pow(max(0, sin(.pi * time / cue.duration)), 1.6)
        let undulation = 0.80 + 0.20 * sin(2 * .pi * 2.1 * time)
        signal = (lowNoise - softerNoise) * envelope * undulation * (cue == .paperFold ? 1.1 : 0.55)
      case .found:
        signal = pluck(at: time, frequency: 220, duration: cue.duration) * 0.32
      case .complete:
        // A spare open fifth, each note allowed to settle before the next.
        signal = pluck(at: time, frequency: 220, duration: cue.duration) * 0.25
        signal += pluck(at: time - 0.38, frequency: 330, duration: cue.duration - 0.38) * 0.19
        signal += pluck(at: time - 0.82, frequency: 440, duration: cue.duration - 0.82) * 0.13
      }
      samples[frame] = Float(max(-0.65, min(0.65, signal)))
    }
    return buffer
  }

  private func pluck(at time: Double, frequency: Double, duration: Double) -> Double {
    guard time >= 0, time < duration else { return 0 }
    let attack = min(1, time / 0.018)
    let release = min(1, (duration - time) / 0.18)
    let phase = 2 * Double.pi * frequency * time
    let fundamental = sin(phase) * exp(-2.6 * time)
    let second = sin(phase * 2.001) * exp(-4.0 * time) * 0.27
    let third = sin(phase * 3.004) * exp(-5.7 * time) * 0.10
    return (fundamental + second + third) * attack * release
  }
}

private enum ScrollSoundCue: CaseIterable {
  case unroll
  case found
  case complete
  case paperFold

  var duration: Double {
    switch self {
    case .unroll: 1.45
    case .found: 1.8
    case .complete: 2.8
    case .paperFold: 0.27
    }
  }
}
