import Foundation
import HotwireNative
import UIKit

final class FlashMessageComponent: BridgeComponent {
    override class var name: String { "flash-message" }

    private struct FlashMessageData: Decodable {
        let title: String
        let body: String?
    }

    override func onReceive(message: Message) {
        guard let data: FlashMessageData = message.data(),
              let viewController = delegate?.destination as? UIViewController else { return }

        let alert = UIAlertController(
            title: data.title,
            message: data.body,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
}
