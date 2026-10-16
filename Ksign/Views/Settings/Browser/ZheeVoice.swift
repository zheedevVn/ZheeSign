import AVFoundation
import Foundation

/// Push-to-talk voice for the mesh channel: hold to record (max 15s),
/// release to send. Voice rides the same encrypted mesh envelope as text.
public enum ZheeVoice {
    static let maxDuration: TimeInterval = 15
}

/// Records a short AAC clip to a temp file, returns its bytes.
/// Messenger-style flow: tap mic to record, trash to cancel,
/// pause/resume, send arrow to send. Nothing sends without tapping send.
final class ZheeVoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Live waveform levels (0...1) from the recorder meter, newest last.
    @Published private(set) var levels: [CGFloat] = []

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var url: URL?
    /// True from tap-mic until finish/cancel. `beginRecording` only runs
    /// while this is still true, so a stray permission callback can never
    /// start a clip after the user already cancelled.
    private var wantsRecording = false
    var onFinish: ((Data?) -> Void)?

    /// Clips shorter than this are accidental taps — drop them, send nothing.
    private static let minDuration: TimeInterval = 0.5

    func start() {
        guard !wantsRecording, !isRecording else { return }
        wantsRecording = true
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.wantsRecording = false; return }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        guard wantsRecording else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            wantsRecording = false
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zheechat-voice-\(UUID().uuidString).m4a")
        self.url = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            isPaused = false
            elapsed = 0
            levels = []
            startTimer()
        } catch {
            isRecording = false
            wantsRecording = false
            self.url = nil
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            elapsed += 0.1
            if let r = recorder {
                r.updateMeters()
                let power = r.averagePower(forChannel: 0)
                let level = max(0, min(1, CGFloat((power + 50) / 50)))
                levels.append(level)
                if levels.count > 48 { levels.removeFirst(levels.count - 48) }
            }
            if elapsed >= ZheeVoice.maxDuration { finish() }
        }
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    func resume() {
        guard isRecording, isPaused else { return }
        recorder?.record()
        isPaused = false
        startTimer()
    }

    /// Stop + discard. Sends nothing.
    func cancel() {
        wantsRecording = false
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPaused = false
        elapsed = 0
        levels = []
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Stop + send (only if the clip is long enough to be intentional).
    func finish() {
        wantsRecording = false
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPaused = false
        let recorded = elapsed
        elapsed = 0
        levels = []
        let data = url.flatMap { try? Data(contentsOf: $0) }
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        if recorded >= Self.minDuration {
            onFinish?(data)
        }
    }
}

/// Plays one voice clip.
final class ZheeVoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func play(_ data: Data) {
        if isPlaying { stop(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        self.player = nil
    }
}
