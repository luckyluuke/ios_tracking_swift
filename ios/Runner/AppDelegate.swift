import UIKit
import Flutter
import Firebase
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import FirebaseAuth
import PushKit
import flutter_callkit_incoming
import flutter_local_notifications
//import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let broadcastChannel = FlutterMethodChannel(name: "my_first_app.stopReplayKitNotification",binaryMessenger: controller.binaryMessenger)
     broadcastChannel.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          guard call.method == "stopReplayKitNotification" else {
            result(FlutterMethodNotImplemented)
            return
          }
          self?.stopReplayKit(result: result)
      })

    GeneratedPluginRegistrant.register(with: self)

    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
            if (!registry.hasPlugin("FlutterForegroundTaskPlugin")) {
               SwiftFlutterForegroundTaskPlugin.register(with: registry.registrar(forPlugin: "FlutterForegroundTaskPlugin")!)
            }
    }

    let userDefaults = UserDefaults.standard
    if !userDefaults.bool(forKey: "appFirstInstall") {
        //if app is first time opened then it will be nil
        userDefaults.setValue(true, forKey: "appFirstInstall")
        userDefaults.synchronize()
        // signOut from Auth
        do{
            try Auth.auth().signOut()
        } catch {

        }
    }

    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /*override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: UIKit.Data) {

     Messaging.messaging().apnsToken = deviceToken
     print("DID Register Token: \(deviceToken)")
     let tmpToken = deviceToken.map { String(format: "%02x", $0) }.joined()
     print("DID Register new Token: \(tmpToken)")
     return super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }*/

  // Handle updated push credentials
  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
      //print(credentials.token)
      let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
      //print("Launching APP for SWIFT with  stored_voipToken=\(deviceToken)")

      //Save deviceToken locally, then use it to save in database later
      let userDefaults = UserDefaults.standard
      userDefaults.setValue(deviceToken, forKey: "flutter.voipToken")
      userDefaults.synchronize()
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
      //print("didInvalidatePushTokenFor")
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  // Handle incoming pushes
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
      //print(" PUSHKIT didReceiveIncomingPushWith")
      guard type == .voIP else { return }

      let id = payload.dictionaryPayload["id"] as? String ?? ""; //"2a3cd86b-00ce-40f9-888a-0fb9c6cd1be8"
      let nameCaller = payload.dictionaryPayload["nameCaller"] as? String ?? ""
      let handle = payload.dictionaryPayload["handle"] as? String ?? ""
      let appMode = payload.dictionaryPayload["appMode"] as? String ?? ""
      let notificationMode = payload.dictionaryPayload["notificationMode"] as? String ?? ""

      /*let userDefaults = UserDefaults.standard
      userDefaults.setValue(notificationMode, forKey: "flutter.notificationMode")*/

      //let listOfActiveCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls()

      if((notificationMode == "LIVE_AUTO_SEARCH_CALL") /*&& (listOfActiveCalls.length <= 1)*/){
        let callerUID = payload.dictionaryPayload["callerUid"] as? String ?? ""
        let tokenCallId = payload.dictionaryPayload["tokenCallId"] as? String ?? ""
        let whiteboardId = payload.dictionaryPayload["whiteboardId"] as? String ?? ""
        let isCallerNewUser = payload.dictionaryPayload["isCallerNewUser"] as? String ?? ""
        let destination = payload.dictionaryPayload["dest"] as? String ?? ""
        let destinationSpot = payload.dictionaryPayload["spotDest"] as? String ?? ""

        let data = flutter_callkit_incoming.Data(id: id, nameCaller: nameCaller, handle: handle, type: 1 /*isVideo ? 1 : 0*/)
        data.extra = [
        "user": "abc@123",
        "platform": "ios",
        "notificationMode":notificationMode,
        "callerUid":callerUID,
        "tokenCallId":tokenCallId,
        "whiteboardId":whiteboardId,
        "isCallerNewUser":isCallerNewUser,
        "dest":destination,
        "spotDest":destinationSpot
        ]
        data.iconName = "CallkitTwo"

        if((appMode != "app_uninstall_mode") /*&& (listOfActiveCalls.length <= 1)*/){
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
        }

      }

      //let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false

      DispatchQueue.main.async{
        completion()
      }
  }

  override func applicationWillTerminate(_ application: UIApplication){
    //print("ApplicationWillTerminate STARTED 0: Closing APP")
    let sem = DispatchSemaphore(value:0)
    var userId = Auth.auth().currentUser?.uid
    if (userId != nil){
        let url = URL(string: "https://europe-west1-hamadoo-3c55c.cloudfunctions.net/enableTerminatedModeForIOSRequest")!
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"

        let params = "userId=" + userId!
        let postData = params.data(using: .utf8)
          request.httpBody = postData //try? JSONSerialization.data(withJSONObject: postData, options: []) //userId!.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            sem.signal();
        })
        task.resume()
        sem.wait()
    }
  }

  override func applicationDidEnterBackground(_ application: UIApplication){

    //print("applicationDidEnterBackground STARTED 0: Closing APP")
    lazy var functions = Functions.functions(region: "europe-west1")
    //print("applicationDidEnterBackground STARTED 1: Closing APP")
    var userId = Auth.auth().currentUser?.uid
    if (userId != nil){
        var data : [String: Any] = ["userId":userId!, "isAppTerminated":true]
        //print("applicationDidEnterBackground STARTED 2: Closing APP for \(userId)")

        functions.httpsCallable("enableTerminatedModeForIOS").call(data, completion: {(result,error) in
                  if let error = error{
                      print("An error occurred while calling enableTerminatedModeForIOS: \(error)" )
                  }
                  print("Results from enableTerminatedModeForIOS: \(result)")
        })
    }
    //print("applicationDidEnterBackground STARTED 3: Closing APP")
  }

    override func applicationWillEnterForeground(_ application: UIApplication){

      //print("applicationWillEnterForeground STARTED 0: Closing APP")
      lazy var functions = Functions.functions(region: "europe-west1")
      //print("applicationWillEnterForeground STARTED 1: Closing APP")
      var userId = Auth.auth().currentUser?.uid
      if (userId != nil){
        var data : [String: Any] = ["userId":userId!, "isAppTerminated":false]
          //print("applicationWillEnterForeground STARTED 2: Closing APP for \(userId)")

          functions.httpsCallable("enableTerminatedModeForIOS").call(data, completion: {(result,error) in
                if let error = error{
                    //print("An error occurred while calling enableTerminatedModeForIOS: \(error)" )
                }
                //print("Results from enableTerminatedModeForIOS: \(result)")
          })


      }
      //print("applicationWillEnterForeground STARTED 3: Closing APP")
    }

    override func applicationDidBecomeActive(_ application: UIApplication){

      //print("applicationDidBecomeActive STARTED 0: Opening APP")
      lazy var functions = Functions.functions(region: "europe-west1")
      //print("applicationDidBecomeActive STARTED 1: Opening APP")
      var userId = Auth.auth().currentUser?.uid
      if (userId != nil){
        var data : [String: Any] = ["userId":userId!, "isAppTerminated":false]
        //print("applicationDidBecomeActive STARTED 2: Opening APP for \(userId)")

        functions.httpsCallable("enableTerminatedModeForIOS").call(data, completion: {(result,error) in
            if let error = error{
                //print("An error occurred while calling enableTerminatedModeForIOS: \(error)" )
            }
            //print("Results from enableTerminatedModeForIOS: \(result)")
        })


      }
      //print("applicationDidBecomeActive STARTED 3: Opening APP")
    }

    func stopReplayKit(result: FlutterResult) {

        let notificationName = "FinishScreenBroadcastExtensionProcessNotification" as CFString
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                            CFNotificationName(notificationName),
                            nil,
                            nil,
                            true)
        result(true)
    }

}
