import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let webCookieStorageKey = "com.uygaria.memket.persistedWebCookies"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      configureWebSessionChannel(for: controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  func configureWebSessionChannel(for controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.uygaria.memket/web_session",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }

      switch call.method {
      case "restoreCookies":
        self.restoreWebCookies(result: result)
      case "saveCookies":
        self.saveWebCookies(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func saveWebCookies(result: @escaping FlutterResult) {
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self = self else {
        result(nil)
        return
      }

      let encodedCookies = cookies
        .filter { self.shouldPersist(cookie: $0) }
        .map { self.encode(cookie: $0) }

      UserDefaults.standard.set(encodedCookies, forKey: self.webCookieStorageKey)
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  private func restoreWebCookies(result: @escaping FlutterResult) {
    guard
      let encodedCookies = UserDefaults.standard.array(forKey: webCookieStorageKey) as? [[String: Any]],
      !encodedCookies.isEmpty
    else {
      result(nil)
      return
    }

    let cookieStore = WKWebsiteDataStore.default().httpCookieStore
    let group = DispatchGroup()

    for encodedCookie in encodedCookies {
      guard let cookie = decodeCookie(from: encodedCookie) else {
        continue
      }

      group.enter()
      cookieStore.setCookie(cookie) {
        group.leave()
      }
    }

    group.notify(queue: .main) {
      result(nil)
    }
  }

  private func shouldPersist(cookie: HTTPCookie) -> Bool {
    let domain = cookie.domain.lowercased()
    let normalizedDomain = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain

    return normalizedDomain == "uygaria.com" || normalizedDomain.hasSuffix(".uygaria.com")
  }

  private func encode(cookie: HTTPCookie) -> [String: Any] {
    let httpOnlyKey = HTTPCookiePropertyKey(rawValue: "HttpOnly")
    var encoded: [String: Any] = [
      "name": cookie.name,
      "value": cookie.value,
      "domain": cookie.domain,
      "path": cookie.path,
      "secure": cookie.isSecure,
      "httpOnly": cookie.properties?[httpOnlyKey] != nil,
    ]

    if let expiresDate = cookie.expiresDate {
      encoded["expires"] = expiresDate.timeIntervalSince1970
    }

    return encoded
  }

  private func decodeCookie(from encoded: [String: Any]) -> HTTPCookie? {
    guard
      let name = encoded["name"] as? String,
      let value = encoded["value"] as? String,
      let domain = encoded["domain"] as? String,
      let path = encoded["path"] as? String
    else {
      return nil
    }

    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: name,
      .value: value,
      .domain: domain,
      .path: path,
    ]

    if let expires = encoded["expires"] as? TimeInterval {
      properties[.expires] = Date(timeIntervalSince1970: expires)
    }

    if encoded["secure"] as? Bool == true {
      properties[.secure] = "TRUE"
    }

    if encoded["httpOnly"] as? Bool == true {
      properties[HTTPCookiePropertyKey(rawValue: "HttpOnly")] = "TRUE"
    }

    return HTTPCookie(properties: properties)
  }
}
