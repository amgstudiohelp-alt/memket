import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return
    }

    appDelegate.configureWebSessionChannel(for: controller)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    persistWebCookies()
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    persistWebCookies()
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    persistWebCookies()
    super.sceneDidDisconnect(scene)
  }

  private func persistWebCookies() {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }

    appDelegate.persistWebCookies()
  }
}
