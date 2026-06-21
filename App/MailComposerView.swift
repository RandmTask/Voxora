import MessageUI
import SwiftUI

struct MailComposerView: UIViewControllerRepresentable {
  var draft: EmailDraft
  var onFinish: () -> Void

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
      self.onFinish = onFinish
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      controller.dismiss(animated: true)
      onFinish()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onFinish: onFinish)
  }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let controller = MFMailComposeViewController()
    controller.mailComposeDelegate = context.coordinator
    controller.setToRecipients(draft.recipients)
    controller.setCcRecipients(draft.ccRecipients)
    controller.setSubject(draft.subject)
    controller.setMessageBody(draft.body, isHTML: false)
    return controller
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
