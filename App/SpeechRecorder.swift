@preconcurrency import AVFoundation
import Foundation
import Observation
@preconcurrency import Speech

@MainActor
@Observable
final class SpeechRecorder {
  private(set) var recording = false
  private(set) var transcript = ""
  private(set) var isAvailable = false
  var errorMessage: String?

  @ObservationIgnored private let engine = AVAudioEngine()
  @ObservationIgnored private var recognizer: SFSpeechRecognizer?
  @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
  @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
  @ObservationIgnored private var hasInputTap = false
  @ObservationIgnored private var starting = false
  @ObservationIgnored private var sessionID = UUID()

  init() {
    #if !targetEnvironment(simulator)
      let localRecognizer = SFSpeechRecognizer(locale: .current)
      recognizer = localRecognizer
      isAvailable = localRecognizer?.supportsOnDeviceRecognition == true
    #endif
  }

  func start() async {
    guard !recording, !starting else { return }
    guard isAvailable, let recognizer, recognizer.supportsOnDeviceRecognition else {
      errorMessage =
        "On-device dictation is not available here. Your words can still begin on the page."
      return
    }
    starting = true
    defer { starting = false }
    errorMessage = nil
    let currentSessionID = UUID()
    sessionID = currentSessionID
    let authorization = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
    guard sessionID == currentSessionID else { return }
    guard authorization == .authorized else {
      errorMessage =
        "Speech access is turned off. You can enable it in Settings, or write your reflection."
      return
    }
    let microphoneGranted = await AVAudioApplication.requestRecordPermission()
    guard sessionID == currentSessionID else { return }
    guard microphoneGranted else {
      errorMessage =
        "Microphone access is turned off. You can enable it in Settings, or write your reflection."
      return
    }
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement)
      try audioSession.setActive(true)
      let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
      recognitionRequest.requiresOnDeviceRecognition = true
      recognitionRequest.shouldReportPartialResults = true
      recognitionRequest.taskHint = .dictation
      request = recognitionRequest
      transcript = ""
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        stop()
        errorMessage = "The microphone is not ready. You can write your reflection below."
        return
      }
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        recognitionRequest.append(buffer)
      }
      hasInputTap = true
      recognitionTask = recognizer.recognitionTask(with: recognitionRequest) {
        [weak self] result, error in
        let spokenWords = result?.bestTranscription.formattedString
        let finished = result?.isFinal == true
        let failed = error != nil
        Task { @MainActor [weak self] in
          guard let self, self.sessionID == currentSessionID else { return }
          if let spokenWords { self.transcript = spokenWords }
          if finished || failed {
            self.stop()
            if failed, self.transcript.isEmpty {
              self.errorMessage = "Dictation paused. You can try again, or write your reflection."
            }
          }
        }
      }
      engine.prepare()
      try engine.start()
      recording = true
    } catch {
      stop()
      errorMessage = "The microphone could not begin. You can still write your reflection."
    }
  }

  func stop() {
    sessionID = UUID()
    if engine.isRunning { engine.stop() }
    if hasInputTap {
      engine.inputNode.removeTap(onBus: 0)
      hasInputTap = false
    }
    request?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    request = nil
    recording = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
