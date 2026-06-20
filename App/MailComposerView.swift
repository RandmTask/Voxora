import MessageUI
import SwiftUI

struct MailComposerView: UIViewControllerRepresentable {
  var draft: EmailDraft

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    @Binding private var isPresented: Bool

    init(isPresented: Binding<Bool>) {
      _isPresented = isPresented
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      isPresented = false
    }
  }

  @Binding var isPresented: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(isPresented: $isPresented)
  }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let controller = MFMailComposeViewController()
    controller.mailComposeDelegate = context.coordinator
    controller.setSubject(draft.subject)
    controller.setMessageBody(draft.body, isHTML: false)
    return controller
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
