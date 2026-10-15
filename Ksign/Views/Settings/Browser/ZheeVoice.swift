import AVFoundation
import Foundation

/// Push-to-talk voice for the mesh channel: hold to record (max 15s),
/// release to send. Voice rides the same encrypted mesh envelope as text.
public enum ZheeVoice {
    static let maxDuration: TimeInterval = 15
}

/// Records a short AAC clip to a temp file, returns its bytes.
final class ZheeVoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var url: URL?
    var onFinish: ((Data?) -> Void)?

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async { self?.beginRecording() }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch { return }
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
            recorder?.record()
            isRecording = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                elapsed += 0.1
                if elapsed >= ZheeVoice.maxDuration { stop() }
            }
        } catch {
            isRecording = false
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        let data = url.flatMap { try? Data(contentsOf: $0) }
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        onFinish?(data)
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
