import Foundation
import HotwireNative
import UIKit

final class FlashMessageComponent: BridgeComponent {
    override class var name: String { "flash-message" }

    override func onReceive(message: Message) {
        guard let data = message.data else { return }

        if let title = data["title"] as? String {
            let alert = UIAlertController(
                title: title,
                message: data["body"] as? String,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))

            DispatchQueue.main.async {
                self.delegate?.present(alert, animated: true)
            }
        }
    }
}
