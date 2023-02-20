import AudioToolbox
import UIKit

/// Allows mocking payment capture celebration UX so that the cha-ching sounds aren't played in unit testing.
protocol PaymentCaptureCelebrationProtocol {
    /// Called when a payment is captured successfully.
    func celebrate()
}

/// Plays a sound and provides haptic feedback when a payment capture has been completed successfully
final class PaymentCaptureCelebration: NSObject, PaymentCaptureCelebrationProtocol {
    private var soundID: SystemSoundID = 0

    func celebrate() {
        playSound()
        shakeDevice()
    }
}

private extension PaymentCaptureCelebration {
    func playSound() {
        guard let path = Bundle.main.path(forResource: "o.caf", ofType: nil) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        AudioServicesAddSystemSoundCompletion(soundID, nil, nil, { (soundId, clientData) -> Void in
            AudioServicesDisposeSystemSoundID(soundId)
          }, nil)

        AudioServicesPlaySystemSound(soundID)
    }

    func shakeDevice() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
