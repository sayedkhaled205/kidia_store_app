import Flutter
import UIKit
import FirebaseCore
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let authApps = FirebaseApp.allApps?.values.filter {
      $0.name.hasPrefix("mobishop-merchant-auth-")
    } ?? []
    let unhandled = Set(URLContexts.filter { context in
      let url = context.url
      guard url.host?.lowercased() == "firebaseauth", url.path == "/link" else { return true }
      let matchingApps = authApps.filter {
        url.scheme?.lowercased() == "app-" + $0.options.googleAppID.replacingOccurrences(of: ":", with: "-").lowercased()
      }
      guard !matchingApps.isEmpty else { return true }
      // Merchant auth is initialized after the scene connects. FlutterFire's
      // scene handler only forwards to the default (push) Firebase app.
      for app in matchingApps {
        if Auth.auth(app: app).canHandle(url) { break }
      }
      // A callback already handled by SDK swizzling must not become an app route.
      return false
    })
    if !unhandled.isEmpty { super.scene(scene, openURLContexts: unhandled) }
  }
}
