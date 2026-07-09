import UserNotifications
import OneSignalExtension

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var receivedRequest: UNNotificationRequest!
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    receivedRequest = request
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    OneSignalExtension.didReceiveNotificationExtensionRequest(
      receivedRequest,
      with: bestAttemptContent,
      withContentHandler: self.contentHandler
    )
  }

  override func serviceExtensionTimeWillExpire() {
    guard let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent else {
      return
    }

    OneSignalExtension.serviceExtensionTimeWillExpireRequest(
      receivedRequest,
      with: bestAttemptContent
    )
    contentHandler(bestAttemptContent)
  }
}
