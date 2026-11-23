import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for activity in connectionOptions.userActivities {
      if activity.activityType == NSUserActivityTypeBrowsingWeb,
         let url = activity.webpageURL {
        (UIApplication.shared.delegate as? AppDelegate)?.handleIncomingReferralURL(url)
      }
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      (UIApplication.shared.delegate as? AppDelegate)?.handleIncomingReferralURL(url)
    }
    super.scene(scene, continue: userActivity)
  }
}
